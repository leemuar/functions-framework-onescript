#!/bin/bash
git clone https://github.com/GoogleCloudPlatform/functions-framework-conformance.git
cd functions-framework-conformance/client
go build
./client -cmd "oscript ../../server.os --port 8080 --source ../../conformance-cloudevent.os --target CloudEventConformance --signature-type cloudevent" -type legacyevent -buildpacks=false
