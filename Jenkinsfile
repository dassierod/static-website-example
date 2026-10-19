
pipeline {
    agent { label 'docker-agent' }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Quality') {
            steps {
                sh '''
                    set -eu

                    echo "Verification des fichiers du projet"
                    test -s index.html
                    test -s Dockerfile

                    echo "Verification du Dockerfile"
                    grep -Eq '^FROM[[:space:]]+nginx:alpine' Dockerfile
                    grep -Eq '^COPY[[:space:]]+\\.[[:space:]]+/usr/share/nginx/html' Dockerfile

                    echo "QUALITY CHECK PASSED"
                '''
            }
        }

        stage('Build Docker') {
            steps {
                sh 'docker build -t static-website:latest .'
            }
        }

        
 stage('Test') {
    steps {
        sh '''
            set -eu

            docker rm -f static-web-test 2>/dev/null || true

            docker run -d --name static-web-test static-website:latest

            echo "Waiting for Nginx..."

            for i in $(seq 1 15); do
                if docker exec static-web-test wget -q --spider http://localhost/; then
                    echo "HTTP TEST PASSED"
                    exit 0
                fi
                sleep 2
            done

            echo "HTTP TEST FAILED"
            docker logs static-web-test
            exit 1
        '''
    }
 }


 stage('Package and Publish') {
    steps {
        withCredentials([
            usernamePassword(
                credentialsId: 'github-ghcr-credentials',
                usernameVariable: 'GHCR_USER',
                passwordVariable: 'GHCR_TOKEN'
            )
        ]) {
            sh '''
                set -eu

                IMAGE="ghcr.io/dassierod/static-website"

                echo "Tagging Docker image"
                docker tag static-website:latest "$IMAGE:${GIT_COMMIT}"

                echo "Logging into GitHub Container Registry"
                export DOCKER_CONFIG="$(mktemp -d)"
                trap 'rm -rf "$DOCKER_CONFIG"' EXIT

                printf '%s' "$GHCR_TOKEN" |
                    docker login ghcr.io -u "$GHCR_USER" --password-stdin

                echo "Publishing commit image"
                docker push "$IMAGE:${GIT_COMMIT}"

                echo "Publishing latest image"
                docker tag "$IMAGE:${GIT_COMMIT}" "$IMAGE:latest"
                docker push "$IMAGE:latest"

                echo "DOCKER IMAGE PUBLISHED"
            '''
        }
    }
}

 }
    post {
        always {
            sh 'docker rm -f static-web-test 2>/dev/null || true'
        }
    }
}
