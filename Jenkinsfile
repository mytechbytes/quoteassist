// QuoteAssist CI/CD — mirrors the MangoCMS pipeline, adapted to this monorepo.
//
// Pipeline: Configure → CI Image (pull) → Checkout → CI Infrastructure → Setup →
//   Compile → Quality Checks (Credo ‖ Dialyzer) → Tests & Coverage → Build & Push →
//   Approval (main) → Deploy → Smoke Test  [+ Rollback action]
//
// Key differences from MangoCMS, all deliberate:
//   * The shared CI runner `mytechbytes-elixir-ci` is OWNED/built by MangoCMS.
//     QuoteAssist only PULLS it (no "CI Image" build stage).
//   * Monorepo: the Elixir app lives in projects/platform (mount/build context).
//   * Shared multi-app server: deploy/rollback touch ONLY the quoteassist service
//     (`--no-deps`) so MangoCMS / MangoGST are never restarted.
//   * CI Postgres uses pgvector/pgvector:pg18 (the platform needs the vector ext).
//
// develop → staging (auto); main → production (manual approval). OCIR is private,
// so every pull/push logs in first. See docs/server-setup-guide.md.

pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 1, unit: 'HOURS')
    buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
  }

  parameters {
    choice(name: 'PIPELINE_ACTION', choices: ['BUILD_AND_DEPLOY', 'ROLLBACK'], description: 'Action to perform')
    string(name: 'ROLLBACK_TAG', defaultValue: '', description: 'Image tag to roll back to, e.g. prd-13 (main) or stg-13 (develop)')
    string(name: 'COVERAGE_THRESHOLD', defaultValue: '70', description: 'Minimum line coverage %% (raise toward 80+ as the app matures)')
  }

  environment {
    OCIR          = 'ap-mumbai-1.ocir.io'
    OCI_NAMESPACE = 'bmsedjmf13c1'
    // Image repos match the shared-server .env / compose conventions.
    PLATFORM_IMAGE = "${OCIR}/${OCI_NAMESPACE}/quoteassist"
    AI_IMAGE       = "${OCIR}/${OCI_NAMESPACE}/quoteassist-ai"
    // Shared CI runner — built & pushed by the MangoCMS pipeline (the owner).
    // This pipeline only pulls it; the tag must match what MangoCMS pushes.
    CI_IMAGE       = "${OCIR}/${OCI_NAMESPACE}/mytechbytes-elixir-ci:1.20.1-otp-29"
    PGVECTOR_IMAGE = 'pgvector/pgvector:pg18'

    // Throwaway CI infra (fixed names — concurrent builds are disabled).
    CI_NETWORK = 'quoteassist-ci'
    CI_DB      = 'quoteassist-postgres-ci'

    // Reusable "run a mix task in the shared CI image" command. Named volumes
    // cache deps/_build/hex/mix and the dialyzer PLT across builds; the workspace
    // is bind-mounted so coverage artifacts (cover/) land back in the workspace.
    DOCKER_RUN = "docker run --rm" +
      " -v ${WORKSPACE}/projects/platform:/app" +
      " -v quoteassist-deps:/app/deps" +
      " -v quoteassist-build:/app/_build" +
      " -v quoteassist-plts:/app/priv/plts" +
      " -v quoteassist-hex:/root/.hex" +
      " -v quoteassist-mix:/root/.mix" +
      " -w /app -e MIX_ENV=test" +
      " -e DATABASE_URL=ecto://postgres:postgres@${CI_DB}:5432/quote_assist_test" +
      " -e SECRET_KEY_BASE=ci-only-secret-key-base-not-used-for-anything-real-0123456789abcdef" +
      " --network ${CI_NETWORK} ${CI_IMAGE}"

    NOTIFY_EMAIL = 'mytechbytes.official@gmail.com'
  }

  stages {
    stage('Configure') {
      steps {
        script {
          if (env.BRANCH_NAME == 'main') {
            env.TARGET        = 'production'
            env.SSH_CRED      = 'production-server-ssh'
            env.DEPLOY_HOST   = '161.118.161.178'
            env.PRODUCTION_USER = 'ubuntu'
            env.COMPOSE_DIR   = '/home/ubuntu/apps'
            env.TAG_PREFIX    = 'prd'
            env.CONTAINER_NAME = 'quoteassist'
            env.ENV_VAR_NAME  = 'QUOTEASSIST_IMAGE_TAG'
            env.APP_URL       = 'https://quoteassist.mytechbytes.in'
          } else if (env.BRANCH_NAME == 'develop') {
            env.TARGET        = 'staging'
            env.SSH_CRED      = 'production-server-ssh'
            env.DEPLOY_HOST   = '161.118.161.178'
            env.PRODUCTION_USER = 'ubuntu'
            env.COMPOSE_DIR   = '/home/ubuntu/apps-stg'
            env.TAG_PREFIX    = 'stg'
            env.CONTAINER_NAME = 'quoteassist-stg'
            env.ENV_VAR_NAME  = 'QUOTEASSIST_STG_IMAGE_TAG'
            env.APP_URL       = 'https://stg.quoteassist.mytechbytes.in'
          } else {
            env.TARGET     = 'ci-only'
            env.TAG_PREFIX = 'pr'
          }
          env.TAG           = "${env.TAG_PREFIX}-${env.BUILD_NUMBER}"
          env.IMAGE_LATEST  = "${env.TAG_PREFIX}-latest"
          // Rollback redeploys the requested tag; a normal run deploys this build.
          env.DEPLOY_TAG = params.PIPELINE_ACTION == 'ROLLBACK' ? params.ROLLBACK_TAG : env.TAG
          echo "─────────────────────────────────────────────"
          echo " Action   : ${params.PIPELINE_ACTION}"
          echo " Branch   : ${env.BRANCH_NAME}  →  ${env.TARGET}"
          echo " Build tag: ${env.TAG}   Deploy tag: ${env.DEPLOY_TAG}"
          echo "─────────────────────────────────────────────"
        }
      }
    }

    stage('CI Image') {
      when { expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } }
      steps {
        // QuoteAssist is a CONSUMER of the shared runner — pull only, never build.
        withCredentials([usernamePassword(credentialsId: 'ocir-credentials', usernameVariable: 'OCIR_USER', passwordVariable: 'OCIR_PASS')]) {
          sh '''
            set -e
            echo "$OCIR_PASS" | docker login "${OCIR}" -u "$OCIR_USER" --password-stdin
            docker pull "${CI_IMAGE}"
          '''
        }
      }
    }

    stage('Checkout') {
      when { expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } }
      steps {
        script {
          env.GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.GIT_BRANCH_NAME  = env.BRANCH_NAME
          echo "Commit ${env.GIT_COMMIT_SHORT} on ${env.GIT_BRANCH_NAME}"
        }
      }
    }

    stage('CI Infrastructure') {
      when { expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } }
      steps {
        sh '''
          set -e
          docker network create "${CI_NETWORK}" 2>/dev/null || true
          docker rm -f "${CI_DB}" 2>/dev/null || true
          docker run -d --name "${CI_DB}" --network "${CI_NETWORK}" \
            -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
            -e POSTGRES_DB=quote_assist_test "${PGVECTOR_IMAGE}"
          echo "Waiting for ${CI_DB} ..."
          for i in $(seq 1 30); do
            docker exec "${CI_DB}" pg_isready -U postgres >/dev/null 2>&1 && echo "postgres ready" && exit 0
            sleep 2
          done
          echo "postgres did not become ready"; exit 1
        '''
      }
    }

    stage('Setup') {
      when { expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } }
      steps {
        sh '''
          set -e
          ${DOCKER_RUN} sh -c "mix deps.get && mix ecto.create && mix ecto.migrate"
        '''
      }
    }

    stage('Compile') {
      when { expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } }
      steps {
        sh '''
          set -e
          ${DOCKER_RUN} sh -c "mix compile --warnings-as-errors"
        '''
      }
    }

    stage('Quality Checks') {
      when { expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } }
      parallel {
        stage('Credo') {
          steps {
            sh '''
              set -e
              ${DOCKER_RUN} sh -c "mix credo --strict"
            '''
          }
        }
        stage('Dialyzer') {
          steps {
            // First build per agent populates the PLT (slow); the quoteassist-plts
            // volume caches it for subsequent runs.
            sh '''
              set -e
              ${DOCKER_RUN} sh -c "mix dialyzer"
            '''
          }
        }
      }
    }

    stage('Tests & Coverage') {
      when { expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' } }
      steps {
        sh '''
          set -e
          ${DOCKER_RUN} sh -c "mix coveralls.json && mix run --no-start ci/check_coverage.exs ${COVERAGE_THRESHOLD}"
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'projects/platform/cover/*.json', allowEmptyArchive: true, fingerprint: true
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
        withCredentials([usernamePassword(credentialsId: 'ocir-credentials', usernameVariable: 'OCIR_USER', passwordVariable: 'OCIR_PASS')]) {
          sh '''
            set -e
            echo "$OCIR_PASS" | docker login "${OCIR}" -u "$OCIR_USER" --password-stdin
            docker buildx build --platform linux/arm64 \
              --label "org.opencontainers.image.revision=${GIT_COMMIT_SHORT}" \
              --label "org.opencontainers.image.version=${TAG}" \
              --label "build.number=${BUILD_NUMBER}" \
              --label "build.branch=${BRANCH_NAME}" \
              -t "${PLATFORM_IMAGE}:${TAG}" \
              -t "${PLATFORM_IMAGE}:${IMAGE_LATEST}" \
              --push projects/platform
            docker logout "${OCIR}"
            # ai-service ships in its own release (Phase 5); until then platform-only:
            # docker buildx build --platform linux/arm64 \
            #   -t "${AI_IMAGE}:${TAG}" -t "${AI_IMAGE}:${IMAGE_LATEST}" \
            #   --push projects/ai-service
          '''
        }
      }
    }

    stage('Approval') {
      when {
        allOf {
          branch 'main'
          expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' }
        }
      }
      steps {
        timeout(time: 24, unit: 'HOURS') {
          input message: "Deploy ${env.TAG} to PRODUCTION?", ok: 'Deploy'
        }
      }
    }

    stage('Deploy') {
      when {
        allOf {
          expression { params.PIPELINE_ACTION == 'BUILD_AND_DEPLOY' }
          anyOf { branch 'main'; branch 'develop' }
        }
      }
      steps {
        // Shared multi-app server: scope every command to the quoteassist service
        // (`--no-deps`) so the shared postgres/redis and other apps are untouched.
        withCredentials([
          sshUserPrivateKey(credentialsId: env.SSH_CRED, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
          usernamePassword(credentialsId: 'ocir-credentials', usernameVariable: 'OCIR_USER', passwordVariable: 'OCIR_PASS')
        ]) {
          sh '''
            set -e
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ${PRODUCTION_USER}@${DEPLOY_HOST} bash -s <<ENDSSH
              set -e
              cd ${COMPOSE_DIR}
              echo "Logging in to OCIR on the server ..."
              echo "${OCIR_PASS}" | docker login ${OCIR} -u "${OCIR_USER}" --password-stdin
              echo "1/5 pin image tag → ${DEPLOY_TAG}"
              sed -i "s|^${ENV_VAR_NAME}=.*|${ENV_VAR_NAME}=${DEPLOY_TAG}|" .env
              echo "2/5 pull ${CONTAINER_NAME}"
              docker compose pull ${CONTAINER_NAME}
              echo "3/5 recreate ${CONTAINER_NAME} (--no-deps)"
              docker compose up -d --no-deps ${CONTAINER_NAME}
              echo "4/5 run migrations"
              docker compose exec -T ${CONTAINER_NAME} /app/bin/quote_assist eval "QuoteAssist.Release.migrate()"
              echo "5/5 verify"
              docker compose ps ${CONTAINER_NAME}
              docker logout ${OCIR}
ENDSSH
          '''
        }
      }
    }

    stage('Rollback') {
      when {
        allOf {
          expression { params.PIPELINE_ACTION == 'ROLLBACK' }
          anyOf { branch 'main'; branch 'develop' }
        }
      }
      steps {
        script {
          if (!params.ROLLBACK_TAG?.trim()) {
            error('ROLLBACK_TAG is required for a ROLLBACK run (e.g. prd-13).')
          }
        }
        withCredentials([
          sshUserPrivateKey(credentialsId: env.SSH_CRED, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
          usernamePassword(credentialsId: 'ocir-credentials', usernameVariable: 'OCIR_USER', passwordVariable: 'OCIR_PASS')
        ]) {
          // Roll back code only — no migrations are run automatically.
          sh '''
            set -e
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ${PRODUCTION_USER}@${DEPLOY_HOST} bash -s <<ENDSSH
              set -e
              cd ${COMPOSE_DIR}
              echo "${OCIR_PASS}" | docker login ${OCIR} -u "${OCIR_USER}" --password-stdin
              echo "1/4 validate ${DEPLOY_TAG} exists in OCIR"
              docker manifest inspect ${PLATFORM_IMAGE}:${DEPLOY_TAG} >/dev/null
              echo "2/4 pin image tag → ${DEPLOY_TAG}"
              sed -i "s|^${ENV_VAR_NAME}=.*|${ENV_VAR_NAME}=${DEPLOY_TAG}|" .env
              echo "3/4 pull + recreate ${CONTAINER_NAME} (--no-deps)"
              docker compose pull ${CONTAINER_NAME}
              docker compose up -d --no-deps ${CONTAINER_NAME}
              echo "4/4 verify"
              docker compose ps ${CONTAINER_NAME}
              docker logout ${OCIR}
ENDSSH
          '''
        }
      }
    }

    stage('Smoke Test') {
      when { anyOf { branch 'main'; branch 'develop' } }
      steps {
        sh '''
          for i in $(seq 1 5); do
            code=$(curl -s -o /dev/null -w "%{http_code}" ${APP_URL}/health/ready || true)
            [ "$code" = "200" ] && echo "smoke ok (${APP_URL})" && exit 0
            echo "attempt $i: HTTP ${code} — retrying"; sleep 5
          done
          echo "smoke test failed for ${APP_URL}"; exit 1
        '''
      }
    }
  }

  post {
    always {
      // Tear down throwaway CI infra and root-owned coverage output (the cached
      // named volumes are intentionally kept for the next build).
      sh '''
        docker rm -f "${CI_DB}" 2>/dev/null || true
        docker network rm "${CI_NETWORK}" 2>/dev/null || true
        docker run --rm -v "${WORKSPACE}/projects/platform":/app -w /app "${CI_IMAGE}" rm -rf cover 2>/dev/null || true
        docker logout "${OCIR}" 2>/dev/null || true
      '''
    }
    success {
      emailext(
        to: env.NOTIFY_EMAIL,
        subject: "✅ QuoteAssist ${env.TARGET} — ${env.JOB_NAME} #${env.BUILD_NUMBER}",
        body: """\
Action : ${params.PIPELINE_ACTION}
Branch : ${env.BRANCH_NAME} (${env.TARGET})
Tag    : ${env.DEPLOY_TAG}
Commit : ${env.GIT_COMMIT_SHORT ?: 'n/a'}
URL    : ${env.APP_URL ?: 'n/a'}
Build  : ${env.BUILD_URL}
"""
      )
    }
    failure {
      emailext(
        to: env.NOTIFY_EMAIL,
        subject: "❌ QuoteAssist ${env.TARGET} FAILED — ${env.JOB_NAME} #${env.BUILD_NUMBER}",
        body: """\
Action : ${params.PIPELINE_ACTION}
Branch : ${env.BRANCH_NAME} (${env.TARGET})
Tag    : ${env.DEPLOY_TAG}
Build  : ${env.BUILD_URL}console
"""
      )
    }
  }
}
