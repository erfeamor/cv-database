pipeline {
    agent any

    stages {
        stage('Validate migrations') {
            steps {
                // Spins up a throwaway MySQL and applies every migration to it,
                // failing the build on any broken SQL.
                sh '''
                    docker network create cv-db-ci-$BUILD_NUMBER
                    docker run -d --rm \
                      --name cv-mysql-ci-$BUILD_NUMBER \
                      --network cv-db-ci-$BUILD_NUMBER \
                      -e MYSQL_ROOT_PASSWORD=root \
                      -e MYSQL_DATABASE=cv \
                      -e MYSQL_USER=cv \
                      -e MYSQL_PASSWORD=cv \
                      mysql:8.4
                    docker run --rm \
                      --network cv-db-ci-$BUILD_NUMBER \
                      -v "$WORKSPACE/sql:/flyway/sql" \
                      -e FLYWAY_URL='jdbc:mysql://cv-mysql-ci-'$BUILD_NUMBER':3306/cv?allowPublicKeyRetrieval=true' \
                      -e FLYWAY_USER=cv \
                      -e FLYWAY_PASSWORD=cv \
                      -e FLYWAY_LOCATIONS=filesystem:/flyway/sql/migrations \
                      -e FLYWAY_CONNECT_RETRIES=60 \
                      flyway/flyway:10 migrate
                '''
            }
            post {
                always {
                    sh '''
                        docker rm -f cv-mysql-ci-$BUILD_NUMBER || true
                        docker network rm cv-db-ci-$BUILD_NUMBER || true
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                // Placeholder: run Flyway against RDS with credentials from
                // SSM Parameter Store once the dev environment exists.
                echo 'Deploy stage not yet implemented'
            }
        }
    }
}
