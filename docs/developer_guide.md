# Foreman Google Developer Guide

## Initial Setup
### Google Cloud Platform
* Create an account and project at [console.cloud.google.com](https://console.cloud.google.com)
* In _API & Services > Credentials_ create new service account (role: `Editor`) 
* On account detail page go to _Keys_ and create new `JSON` key 

### Plugin Installation
```shell
# In Foreman folder:
echo "gem 'foreman_google', path: '../foreman_google'" >> bundler.d/foreman_google.local.rb

bundle install
```

### Setup Google Compute Resource and test data
* In Foreman, go to _Infrastructure > Compute Resources_ and create Compute Resource
```
name: Google
provider: Google
Certificate Path: JSON file
Zone: select the zone you want
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

