# Java Lambda Sample
    
    pushd java

    mvn clean install
    
    popd
    pushd terraform

    aws s3 mb s3://tfstate3671272409937123

    terraform init
    terraform workspace new javadev

    terraform apply -auto-approve

    curl -v $(terraform output url)

    terraform destroy -auto-approve

    popd
