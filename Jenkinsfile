// QuoteAssist CI/CD — builds & deploys the platform (Elixir) and ai-service
// (Python) images to OCIR, then deploys via Docker Compose over SSH.
// See docs/server-setup-guide.md. Replace <OCI_NAMESPACE> or set it as a Jenkins
// global env var. develop → staging (auto); main → production (manual approval).

pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 2, unit: 'HOURS')
  }

  parameters {
    choice(name: 'PIPELINE_ACTION', choices: ['BUILD_AND_DEPLOY', 'ROLLBACK'], description: 'Action to perform')
    string(name: 'ROLLBACK_TAG', defaultValue: '', description: 'e.g. prd-13 (main) or stg-13 (develop)')
    string(name: 'COVERAGE_THRESHOLD', defaultValue: '80', description: 'Minimum coverage %')
  }

  environment {
    OCIR          = 'ap-mumbai-1.ocir.io'
    OCI_NAMESPACE = 'bmsedjmf13c1'
    // Image repos match the shared-server .env / compose conventions.
    PLATFORM_IMAGE = "${OCIR}/${OCI_NAMESPACE}/quoteassist"
    AI_IMAGE       = "${OCIR}/${OCI_NAMESPACE}/quoteassist-ai"
    // Shared CI runner — built & pushed by ONE owner repo (not here). This
    // pipeline only pulls it. Bump the toolchain in the owner repo, not per-app.
    CI_IMAGE       = "${OCIR}/${OCI_NAMESPACE}/mytechbytes-elixir-ci:otp-29"
    PGVECTOR_IMAGE = 'pgvector/pgvector:pg18'
  }

  stages {
    stage('Configure') {
      steps {
        script {
          if (env.BRANCH_NAME == 'main') {
            env.TARGET = 'production'
            env.SSH_CRED = 'production-server-ssh'
            env.DEPLOY_HOST = 'ubuntu@161.118.161.178'
            env.COMPOSE_DIR = '/home/ubuntu/apps'
            env.TAG_PREFIX = 'prd'
            env.APP_URL = 'https://quoteassist.mytechbytes.in'
          } else if (env.BRANCH_NAME == 'develop') {
            env.TARGET = 'staging'
            env.SSH_CRED = 'production-server-ssh'
            env.DEPLOY_HOST = 'ubuntu@161.118.161.178'
            env.COMPOSE_DIR = '/home/ubuntu/apps-stg'
            env.TAG_PREFIX = 'stg'
            env.APP_URL = 'https://stg.quoteassist.mytechbytes.in'
          } else {
            env.TARGET = 'ci-only'
            env.TAG_PREFIX = 'pr'
          }
          env.TAG = "${env.TAG_PREFIX}-${env.BUILD_NUMBER}"
          echo "Branch=${env.BRANCH_NAME} target=${env.TARGET} tag=${env.TAG}"
        }
      }
    }

    stage('Platform CI') {
      when { expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } }
      steps {
        sh '''
          set -e
          # Shared CI runner is owned/built by another repo — just pull the latest.
          docker pull "${CI_IMAGE}"
          docker network create qa-ci-${BUILD_NUMBER} || true
          docker run -d --name qa-ci-db-${BUILD_NUMBER} --network qa-ci-${BUILD_NUMBER} \
            -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=quote_assist_test ${PGVECTOR_IMAGE}
          for i in $(seq 1 20); do docker exec qa-ci-db-${BUILD_NUMBER} pg_isready -U postgres && break; sleep 2; done

          docker run --rm --network qa-ci-${BUILD_NUMBER} \
            -e MIX_ENV=test \
            -e DATABASE_URL=ecto://postgres:postgres@qa-ci-db-${BUILD_NUMBER}:5432/quote_assist_test \
            -v "$PWD/projects/platform":/app -w /app "${CI_IMAGE}" \
            sh -c "mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix credo && mix test"
        '''
      }
      post {
        always {
          sh '''
            docker rm -f qa-ci-db-${BUILD_NUMBER} || true
            docker network rm qa-ci-${BUILD_NUMBER} || true
          '''
        }
      }
    }

    stage('Build & Push') {
      when {
        allOf {
          expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' }
          anyOf { branch 'main'; branch 'develop' }
        }
      }
      steps {
        sh '''
          set -e
          docker buildx build --platform linux/arm64 \
            -t "${PLATFORM_IMAGE}:${TAG}" -t "${PLATFORM_IMAGE}:${TAG_PREFIX}-latest" \
            --push projects/platform
          # ai-service image is built + deployed in its own release (Phase 5). Until
          # then QuoteAssist is platform-only, so we don't build/ship it:
          # docker buildx build --platform linux/arm64 \
          #   -t "${AI_IMAGE}:${TAG}" -t "${AI_IMAGE}:${TAG_PREFIX}-latest" \
          #   --push projects/ai-service
        '''
      }
    }

    stage('Approval') {
      when { allOf { branch 'main'; expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } } }
      steps {
        timeout(time: 24, unit: 'HOURS') {
          input message: "Deploy ${TAG} to PRODUCTION?", ok: 'Deploy'
        }
      }
    }

    stage('Deploy') {
      when {
        anyOf { branch 'main'; branch 'develop' }
      }
      steps {
        script {
          // On rollback, deploy the requested tag instead of the freshly built one.
          def deployTag = params.PIPELINE_ACTION == 'ROLLBACK' ? params.ROLLBACK_TAG : env.TAG
          sshagent(credentials: [env.SSH_CRED]) {
            // Shared multi-app server: touch ONLY the quoteassist service so
            // MangoCMS / others are never restarted.
            sh """
              ssh -o StrictHostKeyChecking=no ${env.DEPLOY_HOST} '
                set -e
                cd ${env.COMPOSE_DIR}
                sed -i "s/^QUOTEASSIST_IMAGE_TAG=.*/QUOTEASSIST_IMAGE_TAG=${deployTag}/" .env
                docker compose pull quoteassist
                docker compose up -d quoteassist
                docker compose exec -T quoteassist /app/bin/quote_assist eval "QuoteAssist.Release.migrate()"
              '
            """
          }
        }
      }
    }

    stage('Smoke Test') {
      when { anyOf { branch 'main'; branch 'develop' } }
      steps {
        sh '''
          for i in $(seq 1 5); do
            code=$(curl -s -o /dev/null -w "%{http_code}" ${APP_URL}/health/ready || true)
            [ "$code" = "200" ] && echo "smoke ok" && exit 0
            sleep 5
          done
          echo "smoke test failed"; exit 1
        '''
      }
    }
  }

  post {
    success { echo "Pipeline OK — ${env.BRANCH_NAME} ${env.TAG}" }
    failure { echo "Pipeline FAILED — ${env.BRANCH_NAME} ${env.TAG}" }
  }
}
