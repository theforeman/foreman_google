# Foreman Google Developer Guide

⚠️⚠ WIP, feel free to contribute ⚠️⚠️

## Plugin Installation
```shell
# In Foreman folder:
echo "gem 'foreman_google', path: '../foreman_google'" >> bundler.d/foreman_google.local.rb

bundle install
```

## Setup Google Compute Resource and test data
* Create account and project at [console.cloud.google.com](https://console.cloud.google.com)
* In Foreman, go to _Infrastructure > Compute Resources_ and create Compute Resource
```
name: Google
provider: Google
Google Project ID: <your-project-id>
Client Email: in console.cloud.google.com go to project detail > Service Accounts
Certificate Path: In console.cloud.google.com go the the service account detail and generate the .json key file 
Zone: select the zone
```
* Go to _Hosts > Operating Systems_ and create new OS
```
name: CentOS_Stream
Major Version: 8
Family: Red Hat
Architectures: x86_64
```
* Go to _Hosts > Provisioning templates_ and assign OS to the _Kickstart default finish_ template
* Go back to the OS and set the _Kickstart default finish_ template as default Finish template
* Go to the Google Compute Resource detail and create new image
```
Name: centos_stream8_image
Operating System: CentOS_Stream 8
Architecture: x86_64
Username: root
image: centos-stream-8-v*
```
* Go to _Infrastructure > Domains_ and create `google` domain
* _Optional:_ Create host group with google compute resource for a quicker host creation

## Links
* [Compute Engine API](https://cloud.google.com/compute/docs/reference/rest/v1/)
* [Ruby Client for the Google Cloud Compute V1 API](https://github.com/googleapis/google-cloud-ruby/tree/main/google-cloud-compute-v1)
