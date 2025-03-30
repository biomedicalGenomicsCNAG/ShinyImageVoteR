include .env
VER=0.0.1

docker-build:
	docker build -t ${DOCKER_REGISTRY}/firebase-sign-in-page:${VER} . && \
	docker push ${DOCKER_REGISTRY}/firebase-sign-in-page:${VER}

docker-run: 
	docker run --env-file .env -p 80:80 firebase-sign-in-page

docker run:
	-e VITE_FIREBASE_API_KEY=your_api_key \
	-e VITE_FIREBASE_AUTH_DOMAIN=your_auth_domain \
	-e VITE_FIREBASE_STORAGE_BUCKET=your_storage_bucket \
	-e VITE_FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id \
	-e VITE_FIREBASE_APP_ID=your_app_id \	
	-e NGINX_ENVSUBST_TEMPLATE_DIR=/etc/nginx/templates
	-e NGINX_ENVSUBST_TEMPLATE_SUFFIX=.template
	-e NGINX_ENVSUBST_OUTPUT_DIR=/usr/share/nginx/html \
	-p 80:80 my-app	

docker-check-env-substituted:
	docker run -it \
	--env-file .env -p 80:80 firebase-sign-in-page \
	/bin/sh -c "cat /usr/share/nginx/html/index.html"

