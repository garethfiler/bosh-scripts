#!/bin/bash -e

bosh alias-env gcpbosh -e 10.0.0.6 --ca-cert <(bosh int ../creds.yml --path /director_ssl/ca)

export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int ../creds.yml --path /admin_password`
MODEL=base

export service_account_email=stackdriver-nozzle@finkit-cf-gcp-exp-01.iam.gserviceaccount.com

if [ ! -f ${service_account_email}.key.json ]; then
    gcloud iam service-accounts keys create ${service_account_email}.key.json \
            --iam-account ${service_account_email}
fi

bosh -e 10.0.0.6 update-cloud-config cloud-config.yml

bosh -e 10.0.0.6 upload-stemcell https://bosh.io/d/stemcells/bosh-google-kvm-ubuntu-trusty-go_agent?v=3421.11
bosh -e 10.0.0.6 upload-release https://storage.googleapis.com/bosh-gcp/beta/stackdriver-tools/latest.tgz

bosh int --vars-store ../cf-deployment-vars.yml \
    --var-file gcp_credentials_json=${service_account_email}.key.json \
    -o ../cf-deployment/operations/gcp.yml \
    -o rolling-updates-to-diego-cells.yml \
    -o downsize.yml \
    -o log-trace-tokens.yml \
    -o add-stackdriver-nozzle.yml \
    -o ${MODEL}-model.yml \
    --var-errs \
    ../cf-deployment/cf-deployment.yml

bosh -e 10.0.0.6 -d cf deploy \
    --var-file gcp_credentials_json=${service_account_email}.key.json \
    --vars-store ../cf-deployment-vars.yml \
    -o ../cf-deployment/operations/gcp.yml \
    -o rolling-updates-to-diego-cells.yml \
    -o downsize.yml \
    -o log-trace-tokens.yml \
    -o add-stackdriver-nozzle.yml \
    -o ${MODEL}-model.yml \
    ../cf-deployment/cf-deployment.yml
