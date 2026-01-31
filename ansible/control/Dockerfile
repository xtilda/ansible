FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    openssh-client \
    sshpass \
 && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir ansible

WORKDIR /ansible
COPY ansible.cfg /etc/ansible/ansible.cfg
COPY inventory.ini /ansible/inventory.ini
COPY playbook.yml /ansible/playbook.yml

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY ssh/id_rsa /root/.ssh/id_rsa
COPY ssh/id_rsa.pub /root/.ssh/id_rsa.pub
RUN chmod 600 /root/.ssh/id_rsa && chmod 644 /root/.ssh/id_rsa.pub

CMD ["/bin/bash"]
