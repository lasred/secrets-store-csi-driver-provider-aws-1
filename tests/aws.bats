#!/usr/bin/env bats
 
load helpers 
 
WAIT_TIME=120
SLEEP_TIME=1
PROVIDER_YAML=../deployment/private-installer.yaml
NAMESPACE=kube-system
CLUSTER_NAME=integ-cluster
POD_NAME=basic-test-mount
export REGION=us-west-2
export ACCOUNT_NUMBER=$(aws --region $REGION  sts get-caller-identity --query Account --output text)
  
setup_file() {
    #Create and initialize cluster 
    eksctl create cluster \
       --name $CLUSTER_NAME \
       --node-type m5.large \
       --nodes 3 \
       --region $REGION
 
   eksctl utils associate-iam-oidc-provider --name $CLUSTER_NAME --approve --region $REGION
    
   eksctl create iamserviceaccount \
       --name basic-test-mount-sa \
       --namespace $NAMESPACE \
       --cluster $CLUSTER_NAME \
       --attach-policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess \
       --attach-policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite \
       --override-existing-serviceaccounts \
       --approve \
       --region $REGION    
    #Install csi secret driver
    helm repo add secrets-store-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts
    helm --namespace=$NAMESPACE install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --set enableSecretRotation=true --set rotationPollInterval=15s 
 
   #Create test secrets
   aws secretsmanager create-secret --name SecretsManagerTest1 --secret-string SecretsManagerTest1Value --region $REGION
   aws secretsmanager create-secret --name SecretsManagerTest2 --secret-string SecretsManagerTest2Value --region $REGION
   aws secretsmanager create-secret --name SecretsManagerSync --secret-string SecretUser --region $REGION
 
   aws ssm put-parameter --name ParameterStoreTest1 --value ParameterStoreTest1Value --type SecureString --region $REGION
   aws ssm put-parameter --name ParameterStoreTestWithLongName --value ParameterStoreTest2Value --type SecureString --region $REGION
 
   aws ssm put-parameter --name ParameterStoreRotationTest --value BeforeRotation --type SecureString --region $REGION
   aws secretsmanager create-secret --name SecretsManagerRotationTest --secret-string BeforeRotation --region $REGION

   aws secretsmanager create-secret --name secretsManagerJson  --secret-string '{"username": "SecretsManagerUser", "password": "PasswordForSecretsManager"}' --region $REGION
    aws ssm put-parameter --name jsonSsm --value '{"username": "ParameterStoreUser", "password": "PasswordForParameterStore"}' --type SecureString --region $REGION


}
 
teardown_file() { 

    eksctl delete cluster \
        --name $CLUSTER_NAME \
        --region $REGION
 
    aws secretsmanager delete-secret --secret-id SecretsManagerTest1 --force-delete-without-recovery --region $REGION
    aws secretsmanager delete-secret --secret-id SecretsManagerTest2 --force-delete-without-recovery --region $REGION
    aws secretsmanager delete-secret --secret-id SecretsManagerSync --force-delete-without-recovery --region $REGION
 
    aws ssm delete-parameter --name ParameterStoreTest1 --region $REGION
    aws ssm delete-parameter --name ParameterStoreTestWithLongName --region $REGION 
 
    aws ssm delete-parameter --name ParameterStoreRotationTest --region $REGION
    aws secretsmanager delete-secret --secret-id SecretsManagerRotationTest --force-delete-without-recovery --region $REGION

    aws ssm delete-parameter --name jsonSsm --region $REGION
     aws secretsmanager delete-secret --secret-id secretsManagerJson --force-delete-without-recovery --region $REGION


}
 
@test "Install aws provider" {
    envsubst < $PROVIDER_YAML | kubectl apply -f - 
    cmd="kubectl --namespace $NAMESPACE wait --for=condition=Ready --timeout=60s pod -l app=csi-secrets-store-provider-aws"
    wait_for_process $WAIT_TIME $SLEEP_TIME "$cmd"
 
    PROVIDER_POD=$(kubectl --namespace $NAMESPACE get pod -l app=csi-secrets-store-provider-aws -o jsonpath="{.items[0].metadata.name}")	
    run kubectl --namespace $NAMESPACE get pod/$PROVIDER_POD
    assert_success
}

@test "secretproviderclasses crd is established" {
    cmd="kubectl wait --namespace $NAMESPACE --for condition=established --timeout=60s crd/secretproviderclasses.secrets-store.csi.x-k8s.io"
    wait_for_process $WAIT_TIME $SLEEP_TIME "$cmd"
 
    run kubectl get crd/secretproviderclasses.secrets-store.csi.x-k8s.io
    assert_success
}
 
@test "deploy aws secretproviderclass crd" {
    envsubst < BasicTestMountSPC.yaml | kubectl --namespace $NAMESPACE apply -f -
 
    cmd="kubectl --namespace $NAMESPACE get secretproviderclasses.secrets-store.csi.x-k8s.io/basic-test-mount-spc -o yaml | grep aws"
    wait_for_process $WAIT_TIME $SLEEP_TIME "$cmd"
}
 
@test "CSI inline volume test with pod portability" {
   kubectl --namespace $NAMESPACE  apply -f BasicTestMount.yaml
   cmd="kubectl --namespace $NAMESPACE  wait --for=condition=Ready --timeout=60s pod/basic-test-mount"
   wait_for_process $WAIT_TIME $SLEEP_TIME "$cmd"
 
   run kubectl --namespace $NAMESPACE  get pod/$POD_NAME
   assert_success
}
 
@test "CSI inline  volume test with rotation - parameter store " {
   result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/ParameterStoreRotationTest)
   [[ "${result//$'\r'}" == "BeforeRotation" ]]
 
   aws ssm put-parameter --name ParameterStoreRotationTest --value AfterRotation --type SecureString --overwrite --region $REGION
   sleep 20
   result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/ParameterStoreRotationTest)
   [[ "${result//$'\r'}" == "AfterRotation" ]]
}
 
@test "CSI inline volume test with rotation - secrets manager " {
   result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/SecretsManagerRotationTest)
   [[ "${result//$'\r'}" == "BeforeRotation" ]]
  
   aws secretsmanager put-secret-value --secret-id SecretsManagerRotationTest --secret-string AfterRotation --region $REGION
   sleep 20
   result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/SecretsManagerRotationTest)
   [[ "${result//$'\r'}" == "AfterRotation" ]]
}
 
@test "CSI inline volume test with pod portability - read ssm parameters from pod" {
   result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/ParameterStoreTest1)
   [[ "${result//$'\r'}" == "ParameterStoreTest1Value" ]]
 
   result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/ParameterStoreTest2)
   [[ "${result//$'\r'}" == "ParameterStoreTest2Value" ]]
}
 
 
@test "CSI inline volume test with pod portability - read secrets manager secrets from pod" {
    result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/SecretsManagerTest1)
    [[ "${result//$'\r'}" == "SecretsManagerTest1Value" ]]
   
    result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/SecretsManagerTest2)
    [[ "${result//$'\r'}" == "SecretsManagerTest2Value" ]]        
}

@test "CSI inline volume test with pod portability - specify jsmePath for parameter store parameter" {
    result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/ssmUsername)
    [[ "${result//$'\r'}" == "ParameterStoreUser" ]]

    result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/ssmPassword)
    [[ "${result//$'\r'}" == "PasswordForParameterStore" ]]

    jsonSSM='{"username": "ParameterStoreUser", "password": "PasswordForParameterStore"}'

    # Ensure json secret itself was successfully mounted
    result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/jsonSsm)
    [[ "${result//$'\r'}" == $jsonSSM ]]
}

@test "CSI inline volume test with pod portability - specify jsmePath for Secrets Manager secret" {
    result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/secretsManagerUsername)
    [[ "${result//$'\r'}" == "SecretsManagerUser" ]]

    result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/secretsManagerPassword)
    [[ "${result//$'\r'}" == "PasswordForSecretsManager" ]]

    jsonSecretsManager='{"username": "SecretsManagerUser", "password": "PasswordForSecretsManager"}'

    result=$(kubectl --namespace $NAMESPACE exec $POD_NAME -- cat /mnt/secrets-store/secretsManagerJson)
    [[ "${result//$'\r'}" == $jsonSecretsManager ]]

    run kubectl get secret --namespace $NAMESPACE secrets-manager-json
    [ "$status" -eq 0 ]

    result=$(kubectl --namespace=$NAMESPACE get secret secrets-manager-json -o jsonpath="{.data.username}" | base64 -d)
    [[ "$result" == "SecretsManagerUser" ]]

    result=$(kubectl --namespace=$NAMESPACE get secret secrets-manager-json -o jsonpath="{.data.password}" | base64 -d)
    [[ "$result" == "PasswordForSecretsManager" ]]
}

@test "Sync with Kubernetes Secret" {
    run kubectl get secret --namespace $NAMESPACE  secret
    [ "$status" -eq 0 ]
 
    result=$(kubectl --namespace=$NAMESPACE get secret secret -o jsonpath="{.data.username}" | base64 -d)
    [[ "$result" == "SecretUser" ]]
}
 
@test "Sync with Kubernetes Secret - Delete deployment. Secret should also be deleted" {
    run kubectl --namespace $NAMESPACE  delete -f BasicTestMount.yaml
    assert_success
 
    run wait_for_process $WAIT_TIME $SLEEP_TIME "check_secret_deleted secret $NAMESPACE"
    assert_success
}
