
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

                    docker exec static-web-test wget -q --spider http://localhost/

                    echo "HTTP TEST PASSED"
                '''
            }
        }
    }

    post {
        always {
            sh 'docker rm -f static-web-test 2>/dev/null || true'
        }
    }
}

