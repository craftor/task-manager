@echo off
cd /d E:\01-AI-Proj\task-manager\android\app
del key.pem cert.pem task-manager-release.keystore 2>nul
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 10000 -subj /CN=TaskManager/OU=Dev/O=Craftor/L=Beijing/ST=Beijing/C=CN
openssl pkcs12 -export -in cert.pem -inkey key.pem -out task-manager-release.keystore -name taskmanager -password pass:taskmanager123