# 商品説明生成API

このAPIは、商品情報と画像を受け取り、Google CloudのGemini AIを使用して商品説明とSEOタグを生成します。

## 機能

- 商品情報（商品名、型番、JANコード、ブランド、価格）を受け取り
- 商品画像を分析して視覚的な特徴を考慮した説明を生成
- Gemini AIを使用して魅力的な商品説明を生成
- SEO最適化のためのキーワードタグを生成
- FastAPIを使用したRESTful APIエンドポイント

## 必要条件

- Python 3.8以上
- Google Cloud Platformアカウント
- Gemini APIへのアクセス権限（画像分析機能付き）
- Google Cloudサービスアカウント

## 環境設定

### サービスアカウントの設定

1. Google Cloud Consoleで新しいサービスアカウントを作成します：
   - IAM & 管理 > サービスアカウント > サービスアカウントを作成
   - 必要な権限を付与（Vertex AI User, Cloud Run Invoker）

2. サービスアカウントキーをダウンロードします：
   - サービスアカウントの詳細ページで「キーを作成」を選択
   - JSONキーをダウンロード
   - ダウンロードしたキーを`service-account-key.json`として保存

### 環境変数の設定

ローカル開発用の`.env`ファイルを作成：
```
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=asia-northeast1
GOOGLE_APPLICATION_CREDENTIALS=./service-account-key.json
```

## ローカルでの実行

1. リポジトリをクローンします：
   ```
   git clone <repository-url>
   cd <repository-directory>
   ```

2. 必要なパッケージをインストールします：
   ```
   pip install -r requirements.txt
   ```

3. サービスアカウントキーを配置します：
   - `service-account-key.json`をプロジェクトルートに配置

4. アプリケーションを起動します：
   ```
   python main.py
   ```

## Cloud Runへのデプロイ

### 方法1: Cloud Buildを使用する（推奨）

1. サービスアカウントキーを準備します：
   - `service-account-key.json`をプロジェクトルートに配置

2. リポジトリをGoogle Cloud Source Repositoryにプッシュします。

3. Cloud Buildトリガーを設定します：
   - Cloud Buildコンソールに移動
   - 「トリガー」→「トリガーの作成」を選択
   - ソースリポジトリとブランチを選択
   - ビルド設定として「cloudbuild.yaml」を指定
   - 環境変数を設定：
     - GOOGLE_CLOUD_PROJECT: プロジェクトID
     - GOOGLE_CLOUD_LOCATION: asia-northeast1

4. トリガーを実行すると、自動的にCloud Runにデプロイされます。

### 方法2: 手動でデプロイする

1. サービスアカウントキーを準備します。

2. Dockerイメージをビルドします：
   ```
   docker build -t gcr.io/[PROJECT_ID]/product-support-api \
     --build-arg GOOGLE_CLOUD_PROJECT=[PROJECT_ID] \
     --build-arg GOOGLE_CLOUD_LOCATION=asia-northeast1 .
   ```

3. イメージをContainer Registryにプッシュします：
   ```
   docker push gcr.io/[PROJECT_ID]/product-support-api
   ```

4. Cloud Runにデプロイします：
   ```
   gcloud run deploy product-support-api \
     --image gcr.io/[PROJECT_ID]/product-support-api \
     --platform managed \
     --region asia-northeast1 \
     --allow-unauthenticated \
     --set-env-vars GOOGLE_CLOUD_PROJECT=[PROJECT_ID],GOOGLE_CLOUD_LOCATION=asia-northeast1
   ```

## APIエンドポイント

### 商品説明生成（画像なし）

```
POST /gemini/product_support
```

リクエストボディ：
```json
{
  "product_name": "商品名",
  "model_number": "型番",
  "jan_code": "JANコード",
  "brand": "ブランド名",
  "price": 1000
}
```

### 商品説明生成（画像あり）

```
POST /gemini/product_support_with_image
```

リクエストボディ（multipart/form-data）：
```
product_name: 商品名
model_number: 型番
jan_code: JANコード
brand: ブランド名
price: 1000
image: [画像ファイル]
```

レスポンス：
```json
{
  "description": "生成された商品説明文",
  "seo_tag": "キーワード1,キーワード2,キーワード3"
}
```

### ヘルスチェック

```
GET /health
```

## フロントエンド連携

このAPIは、商品登録フォームから呼び出して、商品説明とSEOタグを自動生成することができます。商品画像をアップロードすると、画像の内容も考慮した商品説明が生成されます。

## 画像処理機能

- 商品画像をアップロードすると、Gemini AIが画像を分析
- 画像の視覚的な特徴を考慮した商品説明を生成
- 画像がない場合でも、テキスト情報のみで商品説明を生成

## トラブルシューティング

- Gemini APIの初期化に失敗する場合は、認証情報が正しく設定されているか確認してください。
- レスポンスがJSON形式でない場合は、Geminiの出力形式を確認してください。
- 画像アップロードに問題がある場合は、画像サイズや形式を確認してください。
- Cloud Runでのデプロイに問題がある場合は、ログを確認してください。

## ライセンス

MIT 