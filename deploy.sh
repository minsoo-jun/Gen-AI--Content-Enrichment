#!/bin/bash

# エラーが発生したら即座に終了
set -e

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ヘルプメッセージの表示
function show_help {
  echo -e "${BLUE}商品説明生成API デプロイスクリプト${NC}"
  echo ""
  echo "使用方法: ./deploy.sh [オプション]"
  echo ""
  echo "オプション:"
  echo "  -h, --help                このヘルプメッセージを表示"
  echo "  -p, --project PROJECT_ID  Google CloudプロジェクトID"
  echo "  -r, --region REGION       デプロイするリージョン (デフォルト: asia-northeast1)"
  echo "  -s, --service SERVICE_NAME Cloud Runサービス名 (デフォルト: product-support-api)"
  echo "  -i, --image IMAGE_NAME    イメージ名 (デフォルト: product-support-api)"
  echo "  -a, --auth                認証を要求する (デフォルト: 認証なし)"
  echo "  -b, --build-only          ビルドのみ実行し、デプロイは行わない"
  echo "  -d, --deploy-only         デプロイのみ実行し、ビルドは行わない"
  echo ""
  echo "例:"
  echo "  ./deploy.sh -p my-project-id -r us-central1"
  echo "  ./deploy.sh --project my-project-id --region us-central1 --auth"
}

# デフォルト値の設定
PROJECT_ID=""  # 空の文字列に変更
REGION="asia-northeast1"
SERVICE_NAME="product-support-api"
IMAGE_NAME="product-support-api"
AUTH_FLAG="--allow-unauthenticated"
BUILD_ONLY=false
DEPLOY_ONLY=false

# コマンドライン引数の解析
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -p|--project)
      PROJECT_ID="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -s|--service)
      SERVICE_NAME="$2"
      shift 2
      ;;
    -i|--image)
      IMAGE_NAME="$2"
      shift 2
      ;;
    -a|--auth)
      AUTH_FLAG="--no-allow-unauthenticated"
      shift
      ;;
    -b|--build-only)
      BUILD_ONLY=true
      shift
      ;;
    -d|--deploy-only)
      DEPLOY_ONLY=true
      shift
      ;;
    *)
      echo -e "${RED}不明なオプション: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# プロジェクトIDが指定されていない場合はエラー
if [ -z "$PROJECT_ID" ]; then
  echo -e "${RED}エラー: プロジェクトIDが指定されていません。${NC}"
  echo -e "使用方法: ./deploy.sh -p PROJECT_ID"
  exit 1
fi

# イメージ名の完全修飾名を設定
FULL_IMAGE_NAME="gcr.io/${PROJECT_ID}/${IMAGE_NAME}"

# サービスアカウントキーの存在確認
if [ ! -f "service-account-key.json" ]; then
  echo -e "${YELLOW}警告: service-account-key.jsonが見つかりません。${NC}"
  echo -e "Cloud Runへのデプロイにはサービスアカウントキーが必要です。"
  read -p "続行しますか？ (y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# プロジェクトの設定
echo -e "${BLUE}Google Cloudプロジェクトを設定します: ${PROJECT_ID}${NC}"
gcloud config set project "$PROJECT_ID"

# ビルド処理
if [ "$DEPLOY_ONLY" = false ]; then
  echo -e "${BLUE}Cloud Buildを使用してDockerイメージのビルドを開始します...${NC}"
  
  # cloudbuild.yamlが存在するか確認
  if [ ! -f "cloudbuild.yaml" ]; then
    echo -e "${YELLOW}警告: cloudbuild.yamlが見つかりません。${NC}"
    echo -e "Cloud Buildの設定ファイルを作成します..."
    
    # cloudbuild.yamlの作成
    cat > cloudbuild.yaml << EOF
steps:
  # Dockerイメージのビルド
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'gcr.io/\$PROJECT_ID/${IMAGE_NAME}'
      - '--build-arg'
      - 'GOOGLE_CLOUD_PROJECT=\$PROJECT_ID'
      - '--build-arg'
      - 'GOOGLE_CLOUD_LOCATION=${REGION}'
      - '.'
    id: 'build'
  
  # イメージのContainer Registryへのプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - 'gcr.io/\$PROJECT_ID/${IMAGE_NAME}'
    id: 'push'
    waitFor: ['build']
  
  # Cloud Runへのデプロイ
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - '${SERVICE_NAME}'
      - '--image'
      - 'gcr.io/\$PROJECT_ID/${IMAGE_NAME}'
      - '--platform'
      - 'managed'
      - '--region'
      - '${REGION}'
      - '${AUTH_FLAG}'
      - '--set-env-vars'
      - 'GOOGLE_CLOUD_PROJECT=\$PROJECT_ID,GOOGLE_CLOUD_LOCATION=${REGION}'
    id: 'deploy'
    waitFor: ['push']
    allowFailure: true

images:
  - 'gcr.io/\$PROJECT_ID/${IMAGE_NAME}'

substitutions:
  _REGION: ${REGION}
  _SERVICE_NAME: ${SERVICE_NAME}
  _AUTH_FLAG: ${AUTH_FLAG}
  _BUILD_ONLY: false
EOF
    echo -e "${GREEN}cloudbuild.yamlを作成しました。${NC}"
  fi
  
  # Cloud Buildの実行
  if [ "$BUILD_ONLY" = true ]; then
    echo -e "${BLUE}Cloud Buildを実行します（ビルドのみ）...${NC}"
    gcloud builds submit --config=cloudbuild.yaml \
      --substitutions="_BUILD_ONLY=true,_REGION=$REGION,_SERVICE_NAME=$SERVICE_NAME,_AUTH_FLAG=$AUTH_FLAG"
  else
    echo -e "${BLUE}Cloud Buildを実行します...${NC}"
    gcloud builds submit --config=cloudbuild.yaml \
      --substitutions="_BUILD_ONLY=false,_REGION=$REGION,_SERVICE_NAME=$SERVICE_NAME,_AUTH_FLAG=$AUTH_FLAG"
  fi
  
  echo -e "${GREEN}Cloud Buildが完了しました。${NC}"
fi

# デプロイ処理（Cloud Buildでデプロイしない場合）
if [ "$BUILD_ONLY" = true ] && [ "$DEPLOY_ONLY" = false ]; then
  echo -e "${BLUE}Cloud Runへのデプロイを開始します...${NC}"
  
  gcloud run deploy "$SERVICE_NAME" \
    --image "$FULL_IMAGE_NAME" \
    --platform managed \
    --region "$REGION" \
    $AUTH_FLAG \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GOOGLE_CLOUD_LOCATION=$REGION"
  
  echo -e "${GREEN}デプロイが完了しました。${NC}"
  
  # サービスURLの表示
  SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format="value(status.url)")
  echo -e "${BLUE}サービスURL: ${GREEN}$SERVICE_URL${NC}"
fi

echo -e "${GREEN}処理が完了しました。${NC}" 