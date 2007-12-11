openssl x509 -req -days 365 -CA server.crt -CAkey server.key -CAcreateserial -in server.csr -extfile extensions -out server.crt
