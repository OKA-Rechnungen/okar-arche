#!/bin/bash                                                                                                                    

echo "fetching transkriptions from data_repo"
rm -rf data/editions
curl -LO https://github.com/oka-rechnungen/okar-data/archive/refs/heads/main.zip
unzip main

mv okar-data-main/data/editions data

rm main.zip
rm -rf ./okar-data-main

