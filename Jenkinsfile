
pipeline {
    agent { label 'docker-agent' }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
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
                    docker rm -f static-web-test || true
                    docker run -d --name static-web-test static-website:latest
                    docker exec static-web-test wget -q --spider http://localhost/
                '''
            }
        }
    }

    post {
        always {
            sh 'docker rm -f static-web-test || true'
        }
    }
}
