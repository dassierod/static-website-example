
@Library('devops-library') _

pipeline {
    agent { label 'docker-agent' }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE = 'ghcr.io/dassierod/static-website'
        LOCAL_IMAGE = 'static-website:latest'
        DEPLOY_HOST = '172.31.22.213'
    }

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

                    echo "=== QUALITY CHECK ==="

                    test -s index.html
                    test -f Dockerfile
                    test -f scripts/deploy.sh

                    bash -n scripts/deploy.sh

                    echo "QUALITY CHECK PASSED"
                '''
            }
        }

        stage('Build Docker') {
            steps {
                dockerBuild('static-website:latest')
            }
        }

        stage('Test') {
            steps {
                sh '''
                    set -eu

                    echo "=== TEST HTTP ==="

                    docker rm -f static-web-test 2>/dev/null || true

                    docker run -d \
                        --name static-web-test \
                        static-website:latest

                    echo "Waiting for Nginx..."

                    for i in $(seq 1 15); do
                        if docker exec static-web-test \
                            wget -q --spider http://localhost/; then

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

                        echo "=== PUBLISH TO GHCR ==="

                        printf '%s' "$GHCR_TOKEN" | \
                            docker login ghcr.io \
                            -u "$GHCR_USER" \
                            --password-stdin

                        docker tag "$LOCAL_IMAGE" "$IMAGE:$GIT_COMMIT"

                        docker push "$IMAGE:$GIT_COMMIT"

                        docker tag "$LOCAL_IMAGE" "$IMAGE:latest"

                        docker push "$IMAGE:latest"

                        docker logout ghcr.io

                        echo "DOCKER IMAGE PUBLISHED"
                    '''
                }
            }
        }

        stage('Test Automatic Rollback') {
            steps {
                sh '''
                    set -eu

                    echo "=== TEST DU ROLLBACK ==="

                    cp scripts/deploy.sh /tmp/deploy-rollback-test.sh

                    sed -i \
                        's/CONTAINER="static-website-prod"/CONTAINER="static-website-rollback-test"/' \
                        /tmp/deploy-rollback-test.sh

                    sed -i \
                        's/-p 80:80/-p 8085:80/g' \
                        /tmp/deploy-rollback-test.sh

                    sed -i \
                        's|http://localhost/|http://localhost:8085/|g' \
                        /tmp/deploy-rollback-test.sh

                    bash -n /tmp/deploy-rollback-test.sh

                    docker rm -f static-website-rollback-test \
                        2>/dev/null || true

                    docker run -d \
                        --name static-website-rollback-test \
                        -p 8085:80 \
                    static-website:latest

                    echo "Attente du démarrage de Nginx..."

                      READY=false

                     for i in $(seq 1 15); do
                       if curl -fsS --max-time 3 \
                      http://localhost:8085/ -o /dev/null; then
                      READY=true
                      break
                      fi

                      sleep 2
                      done

                       if [ "$READY" != "true" ]; then
                       docker logs static-website-rollback-test
                       exit 1
                      fi

                    echo "Simulation d'un échec..."

                    if SIMULATE_DEPLOY_FAILURE=true \
                        bash /tmp/deploy-rollback-test.sh; then

                        echo "ERREUR : le déploiement aurait dû échouer."
                        exit 1
                    fi

                    echo "Vérification du conteneur restauré..."

                    docker inspect \
                        -f '{{.State.Running}}' \
                        static-website-rollback-test | grep -qx true

                    curl --fail \
                        --retry 10 \
                        --retry-delay 2 \
                        --retry-connrefused \
                        --max-time 3 \
                        http://localhost:8085/ \

                    echo "TEST ROLLBACK SUCCESS"
                '''
            }
        }

        stage('Deploy to AWS') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'aws-deploy-ssh',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -eu

                        echo "=== DEPLOY TO AWS ==="

                        ssh -i "$SSH_KEY" \
                            -o IdentitiesOnly=yes \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=yes \
                            -o UserKnownHostsFile=/home/ubuntu/.ssh/known_hosts \
                            "$SSH_USER@$DEPLOY_HOST" \
                            "IMAGE='$IMAGE:$GIT_COMMIT' bash -s" \
                            < scripts/deploy.sh

                        echo "AWS DEPLOYMENT COMPLETED"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                docker rm -f static-web-test \
                    2>/dev/null || true

                docker rm -f static-website-rollback-test \
                    2>/dev/null || true

                rm -f /tmp/deploy-rollback-test.sh
            '''
        }

        success {
            echo 'PIPELINE SUCCESS'
        }

        failure {
            echo 'PIPELINE FAILED'
        }
    }
}
