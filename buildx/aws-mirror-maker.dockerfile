FROM amazon/aws-cli:2.11.8
RUN yum install -y jq
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$(uname -m | sed 's/aarch64/arm64/g;s/x86_64/amd64/g')/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
COPY ./scripts/mirror-maker.sh /bin
ENTRYPOINT [ "mirror-maker.sh" ]
