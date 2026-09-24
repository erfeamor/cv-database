pipeline {
    agent any

    options {
        // Normal builds take ~90-100 s; 10 min is ~6x that, leaving room for
        // cold image pulls. Without a bound a hung build holds the single
        // executor indefinitely, and the CI-host reaper only stops the host
        // once busyExecutors == 0, so a hang also keeps the host (and its
        // bill) running.
        timeout(time: 10, unit: 'MINUTES')
    }

    stages {
        stage('Validate migrations') {
            steps {
                // Spins up a throwaway MySQL and applies every migration to it,
                // failing the build on any broken SQL.
                //
                // Health probe: a real query as cv/cv against db cv over TCP
                // (127.0.0.1). TCP matters because the entrypoint's init-phase
                // server runs with --skip-networking, so it cannot pass; and a
                // query (unlike `mysqladmin ping`, which exits 0 even on
                // "Access denied") proves the cv user and database exist.
                //
                // The wait loop has its own 120 s bound, well inside the
                // pipeline timeout, so "never healthy" fails fast and with a
                // distinct message. MYSQL_HEALTH_WAIT_SECONDS exists only so the
                // failure path can be exercised locally; the default is the bound.
                //
                // FLYWAY_CONNECT_RETRIES stays as a small safety net only:
                // Flyway starts after MySQL is healthy, so the retry backoff is
                // no longer the synchronisation mechanism.
                sh '''
                    docker network create cv-db-ci-$BUILD_NUMBER
                    docker run -d --rm \
                      --name cv-mysql-ci-$BUILD_NUMBER \
                      --network cv-db-ci-$BUILD_NUMBER \
                      -e MYSQL_ROOT_PASSWORD=root \
                      -e MYSQL_DATABASE=cv \
                      -e MYSQL_USER=cv \
                      -e MYSQL_PASSWORD=cv \
                      --health-cmd "mysql -h127.0.0.1 -ucv -pcv -e 'SELECT 1' cv" \
                      --health-interval 2s \
                      --health-timeout 5s \
                      --health-retries 30 \
                      --health-start-period 30s \
                      mysql:8.4

                    wait_bound=${MYSQL_HEALTH_WAIT_SECONDS:-120}
                    deadline=$(( $(date +%s) + wait_bound ))
                    status=starting
                    while [ "$(date +%s)" -lt "$deadline" ]; do
                        # inspect prints an empty line even when the container is
                        # gone, so set "missing" on its exit status, not its output.
                        if ! status=$(docker inspect -f '{{.State.Health.Status}}' cv-mysql-ci-$BUILD_NUMBER 2>/dev/null); then
                            status=missing
                        fi
                        if [ "$status" = healthy ]; then
                            break
                        fi
                        if [ "$status" = missing ]; then
                            # --rm removed a crashed container: fail now, not at the bound.
                            echo "MySQL did not become healthy within ${wait_bound}s (container exited)" >&2
                            exit 1
                        fi
                        sleep 2
                    done
                    if [ "$status" != healthy ]; then
                        echo "MySQL did not become healthy within ${wait_bound}s (last status: $status)" >&2
                        docker logs --tail 50 cv-mysql-ci-$BUILD_NUMBER >&2 || true
                        exit 1
                    fi
                    echo "MySQL healthy; running Flyway"

                    docker run --rm \
                      --name cv-flyway-ci-$BUILD_NUMBER \
                      --network cv-db-ci-$BUILD_NUMBER \
                      -v "$WORKSPACE/sql:/flyway/sql" \
                      -e FLYWAY_URL='jdbc:mysql://cv-mysql-ci-'$BUILD_NUMBER':3306/cv?allowPublicKeyRetrieval=true' \
                      -e FLYWAY_USER=cv \
                      -e FLYWAY_PASSWORD=cv \
                      -e FLYWAY_LOCATIONS=filesystem:/flyway/sql/migrations \
                      -e FLYWAY_CONNECT_RETRIES=3 \
                      flyway/flyway:13.7.0 migrate
                '''
            }
            post {
                always {
                    sh '''
                        docker rm -f cv-mysql-ci-$BUILD_NUMBER || true
                        docker rm -f cv-flyway-ci-$BUILD_NUMBER || true
                        docker network rm cv-db-ci-$BUILD_NUMBER || true
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                branch 'master'
            }
            steps {
                // Not implemented. Credentials and blast radius are open
                // questions (T-005 on the cv-project board); read the board
                // before implementing.
                echo 'Deploy stage not yet implemented'
            }
        }
    }
}
