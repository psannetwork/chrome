wget https://github.com/ollama/ollama/releases/download/v0.5.11/ollama-linux-amd64.tgz
mkdir -p ~/ollama
tar -xvzf ollama-linux-amd64.tgz -C ~/ollama
echo 'export PATH=$PATH:~/ollama' >> ~/.bashrc



nohup bash -c 'exec -a myhiddenprocess ~/ollama/bin/ollama serve' > /dev/null 2>&1 &





#!/bin/bash

export PATH=$PATH:~/ollama

while true; do
    ollama serve
    echo "Ollama crashed or stopped. Restarting in 5 seconds..."
    sleep 5
done &
