pipeline {
	agent {label 'general'}

	parameters {
		booleanParam(
			name: 'ENABLE_BUILD',
			defaultValue: true,
			description: 'Build App'
		)
		string(
			name: 'GIT_CREDENTIALS',
			defaultValue: 'bitbucket',
			description: 'git credentials'
		)
		string(
			name: 'GIT_URL',
			defaultValue: 'https://github.com/Ilhasoft/docker_kannel.git',
			description: 'Git Repository URL'
		)
		string(
			name: 'GIT_BRANCH',
			defaultValue: 'master',
			description: 'Git Repository BRANCH'
		)
		string(
			name: 'DOCKER_IMAGE_NAME',
			defaultValue: 'weniai/kannel',
			description: 'Docker image name'
		)
		string(
			name: 'DOCKER_IMAGE_TAG',
			defaultValue: 'latest',
			description: 'Docker image version to be used'
		)
		string(
			name: 'DOCKER_REGISTRY_CREDENTIALS',
			defaultValue: 'dockerhub_weni_admin',
			description: 'Docker registry credentials'
		)
		string(
			name: 'DOCKER_REGISTRY_URL',
			defaultValue: '',
			description: 'Docker registry urls'
		)
	}

	stages{
		stage('Build Image') {
			when {
				expression { params.ENABLE_BUILD }
			}
			steps {
				script {
					docker.build("${params.DOCKER_IMAGE_NAME}")
				}
			}
		}
		stage('Push Image') {
			when {
				expression { params.ENABLE_BUILD }
			}
			steps {
				script {
					def image=docker.build("${params.DOCKER_IMAGE_NAME}")
					docker.withRegistry("${params.DOCKER_REGISTRY_URL}", "${params.DOCKER_REGISTRY_CREDENTIALS}") {
						if( BRANCH_NAME.startsWith("release-") ){
							image.push("${params.DOCKER_IMAGE_TAG}")
						}else{
							image.push(BRANCH_NAME.minus('release-'))
						}
					}
				}
			}
		}
	}
}

