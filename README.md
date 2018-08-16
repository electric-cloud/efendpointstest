# EF Plugin Endpoints PoC

This is a proof of concept for EF Plugin Endpoints as described in [Plugin-created Flow API endpoints](http://wiki.electric-cloud.com/display/ecplugins/Plugin-created+Flow+API+endpoints)
It works by running a http server at port 8888 and, whenever there's a relevant http request, eval'ing a DSL contained in plugin's EC-Github property at `/ec_endpoints/webhook/dsl`, which, in turn, runs procedure `do nothing` in project `default`. Originally it is intended to work as a github webhook.

## Setup
1. Clone this repo:
```git clone https://github.com/vsavinoff/efendpointstest.git /opt/electriccloud/mockflow```
2. Set up and run a systemd service:
```
cp /opt/electriccloud/mockflow/mockflow.service /etc/systemd/system
systemctl daemon-reload
systemctl restart mockflow.service
```
3. Log in to EF server and create the necessary stuff inside:
```
/opt/electriccloud/electriccommander/bin/ectool login username password
/opt/electriccloud/electriccommander/bin/ectool evalDsl --dslFile /opt/electriccloud/mockflow/EC-Github.dsl
```
4. (optional) Configure a github webhook to your newly created endpoint at http://HOSTNAME:8888/endpoints/EC-Github/1.0/webhook

5. Enjoy!
