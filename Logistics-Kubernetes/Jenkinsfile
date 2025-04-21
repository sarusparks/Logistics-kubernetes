pipeline{
    agent any
    options{
        disableConcurrentBuilds()
        disableResume()
        timeout(time: 1, unit: "HOURS")
    }
    environment {
        BACKEND_VERSION = ''
        FRONTEND_VERSION = ''
        RELEASE_VERSION = 'V1.0.1'
        APP_VERSION = 'V1.0.1'
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION = "us-east-1"
    }
    parameters{
        choice(name: 'ENVIRONMENT', choices: ['DEV', 'UAT', 'PROD'], description: 'Choose the environment')
        choice(name: 'OPERATION', choices: ['Release', 'Roleback'], description: 'Choose the operation')
    }
    stages{
        stage('Setup'){
            steps{
                script {
                    // Validate parameters
                    if (!params.ENVIRONMENT || !params.OPERATION) {
                        error "Environment or Operation not specified!"
                    }
                    echo "Running ${params.OPERATION} for ${params.ENVIRONMENT}"
                }
            } 
        }

        stage('Versions-Imports'){   
            steps {
                // This copies the `image-version.txt` from the last successful build of project-build
                copyArtifacts(
                    projectName: 'project-build-backend',
                    filter: 'image-version.txt',
                    selector: lastSuccessful()
                )
                script {
                    BACKEND_VERSION = readFile('image-version.txt').trim()
                    echo "backend:version: ${BACKEND_VERSION}"
                    // Use this version for Kubernetes deploy, tagging, etc.
                }
                copyArtifacts(
                    projectName: 'project-build-frontend',
                    filter: 'image-version.txt',
                    selector: lastSuccessful()
                )
                script {
                    FRONTEND_VERSION = readFile('image-version.txt').trim()
                    echo "frontend:version: ${FRONTEND_VERSION}"
                    // Use this version for Kubernetes deploy, tagging, etc.
                }
            }
        }

        stage('EKS Login') {
                steps {
                    script{
                        sh """
                            aws eks update-kubeconfig --region us-east-1 --name fusioniq-${params.ENVIRONMENT.toLowerCase()}
                            kubectl get nodes
                            kubectl apply -f namespace.yaml
                        """
                    }
                }
        }
        stage('Deploy'){   
            steps {
                script {
                    if (params.OPERATION == "Release") {
                        echo "${params.ENVIRONMENT} stage Deploy"
                        if (params.ENVIRONMENT == 'PROD') {
                            // Require manual approval for PROD
                            input message: "Approve for Release in PROD environment?"
                        } 
                        sh """
                            sed -i "s/^appVersion: .*/appVersion: ${APP_VERSION}/" ./Helm/backend/Chart.yaml
                            helm upgrade --install backend ./Helm/backend \
                                --set image.tag=${BACKEND_VERSION} \
                                --set releaseVersion=${RELEASE_VERSION} \
                                --namespace fusioniq

                            sed -i "s/^appVersion: .*/appVersion: ${APP_VERSION}/" ./Helm/frontend/Chart.yaml
                            helm upgrade --install frontend ./Helm/frontend \
                                --set image.tag=${FRONTEND_VERSION} \
                                --set releaseVersion=${RELEASE_VERSION} \
                                --namespace fusioniq

                            kubectl get svc -n fusioniq
                        """
                    } else if (params.OPERATION == "Roleback") {
                        echo "${params.ENVIRONMENT} stage rollback"

                        if (params.ENVIRONMENT == 'PROD') {
                            input message: "Approve rollback in PROD environment?"
                        }

                        sh '''
                            # Get current revision
                            CURRENT_BE_REV=$(helm history backend -n fusioniq -o json | jq '.[] | select(.status == "deployed") | .revision')
                            BACKEND_PREV_REV=$(helm history backend -n fusioniq -o json | jq --argjson cur "$CURRENT_BE_REV" '.[] | select(.revision < $cur) | .revision' | sort -nr | head -1)
                            
                            echo "Current backend revision $CURRENT_BE_REV"
                            echo "Previous backend revision $BACKEND_PREV_REV"

                            if [ -n "$BACKEND_PREV_REV" ]; then
                                echo "Rolling back backend to revision $BACKEND_PREV_REV"
                                helm rollback backend "$BACKEND_PREV_REV" -n fusioniq
                            else
                                echo "No valid previous revision found for backend rollback."
                            fi

                            # Same for frontend

                            CURRENT_FE_REV=$(helm history frontend -n fusioniq -o json | jq '.[] | select(.status == "deployed") | .revision')
                            FRONTEND_PREV_REV=$(helm history frontend -n fusioniq -o json | jq --argjson cur "$CURRENT_FE_REV" '.[] | select(.revision < $cur) | .revision' | sort -nr | head -1)
                            
                            echo "Current backend revision $CURRENT_FE_REV"
                            echo "Previous backend revision $FRONTEND_PREV_REV"

                            if [ -n "$FRONTEND_PREV_REV" ]; then
                                echo "Rolling back frontend to revision $FRONTEND_PREV_REV"
                                helm rollback frontend "$FRONTEND_PREV_REV" -n fusioniq
                            else
                                echo "No valid previous revision found for frontend rollback."
                            fi


                        '''

                    }

                }
            }        
        }

        // stage('Save Current Version') {
        //     steps {
        //         script {
        //             def CURRENT-VERSION = RELEASE_VERSION
        //             echo "Version Released: ${CURRENT-VERSION}"
        //             // Save version to a file
        //             writeFile file: 'current-version.txt', text: CURRENT-VERSION
        //         }
        //     }
        // }
    }
}