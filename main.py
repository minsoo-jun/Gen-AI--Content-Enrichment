import os
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from google.cloud import aiplatform
from dotenv import load_dotenv
import json
import base64
from typing import Optional
import io

# 環境変数の読み込み（Cloud Runでは.envファイルは使用しない）
if os.path.exists('.env'):
    load_dotenv()

# FastAPIアプリケーションの初期化
app = FastAPI(title="Product Support API", description="商品説明とSEOタグを生成するAPI")

# リクエストモデルの定義（画像なしの場合用）
class ProductRequest(BaseModel):
    product_name: str
    model_number: str
    jan_code: str
    brand: str
    price: int

# レスポンスモデルの定義
class ProductResponse(BaseModel):
    description: str
    seo_tag: str

# Geminiモデルの初期化
def init_gemini():
    try:
        # Google Cloud認証情報の設定
        project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        location = os.getenv("GOOGLE_CLOUD_LOCATION", "asia-northeast1")
        
        # Vertex AIの初期化
        aiplatform.init(project=project_id, location=location)
        
        # Geminiモデルの取得
        model = aiplatform.GenerativeModel("gemini-pro")
        return model
    except Exception as e:
        print(f"Geminiモデルの初期化エラー: {e}")
        return None

# 商品説明とSEOタグの生成（画像あり）
def generate_product_content_with_image(model, product_data, image_data=None):
    try:
        # プロンプトの作成
        prompt = f"""
        以下の商品情報に基づいて、魅力的な商品説明とSEOタグを生成してください。
        
        商品名: {product_data.product_name}
        型番: {product_data.model_number}
        JANコード: {product_data.jan_code}
        ブランド: {product_data.brand}
        価格: {product_data.price}円
        """
        
        # 画像がある場合は画像分析も行う
        if image_data:
            # 画像をBase64エンコード
            image_bytes = image_data.file.read()
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')
            
            # 画像を含むプロンプトを作成
            prompt += f"""
            
            商品画像も提供されています。画像の内容を分析し、商品の見た目や特徴を考慮して説明を生成してください。
            """
            
            # 画像付きでGeminiモデルを使用
            response = model.generate_content(
                [
                    prompt,
                    {"mime_type": "image/jpeg", "data": image_base64}
                ]
            )
        else:
            # 画像なしでGeminiモデルを使用
            response = model.generate_content(prompt)
        
        response_text = response.text
        
        # レスポンスをJSONとして解析
        try:
            # レスポンスからJSON部分を抽出
            json_str = response_text.strip()
            if json_str.startswith("```json"):
                json_str = json_str[7:]
            if json_str.endswith("```"):
                json_str = json_str[:-3]
            
            result = json.loads(json_str)
            return result
        except json.JSONDecodeError:
            # JSON解析に失敗した場合、テキストを直接使用
            return {
                "description": response_text,
                "seo_tag": f"{product_data.brand},{product_data.product_name}"
            }
    except Exception as e:
        print(f"コンテンツ生成エラー: {e}")
        return {
            "description": f"{product_data.brand}の{product_data.product_name}は、高品質な製品です。型番{product_data.model_number}、JANコード{product_data.jan_code}で、価格は{product_data.price}円です。",
            "seo_tag": f"{product_data.brand},{product_data.product_name}"
        }

# 商品説明生成エンドポイント（画像なし）
@app.post("/gemini/product_support", response_model=ProductResponse)
async def generate_product_support(request: ProductRequest):
    # Geminiモデルの初期化
    model = init_gemini()
    if not model:
        raise HTTPException(status_code=500, detail="Geminiモデルの初期化に失敗しました")
    
    # 商品説明とSEOタグの生成
    result = generate_product_content_with_image(model, request)
    
    return ProductResponse(
        description=result.get("description", ""),
        seo_tag=result.get("seo_tag", "")
    )

# 商品説明生成エンドポイント（画像あり）
@app.post("/gemini/product_support_with_image", response_model=ProductResponse)
async def generate_product_support_with_image(
    product_name: str = Form(...),
    model_number: str = Form(...),
    jan_code: str = Form(...),
    brand: str = Form(...),
    price: int = Form(...),
    image: Optional[UploadFile] = File(None)
):
    # 商品データの作成
    product_data = ProductRequest(
        product_name=product_name,
        model_number=model_number,
        jan_code=jan_code,
        brand=brand,
        price=price
    )
    
    # Geminiモデルの初期化
    model = init_gemini()
    if not model:
        raise HTTPException(status_code=500, detail="Geminiモデルの初期化に失敗しました")
    
    # 商品説明とSEOタグの生成
    result = generate_product_content_with_image(model, product_data, image)
    
    return ProductResponse(
        description=result.get("description", ""),
        seo_tag=result.get("seo_tag", "")
    )

# ヘルスチェックエンドポイント
@app.get("/health")
async def health_check():
    return {"status": "healthy"}

# ルートエンドポイント
@app.get("/")
async def root():
    return {"message": "Product Support API is running"}

# アプリケーションの起動（Cloud Runではこの部分は使用されない）
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True) 