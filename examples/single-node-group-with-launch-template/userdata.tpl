MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash

set -uxo pipefail

# Test to see if the Nitro enclaves module is loaded
lsmod | grep -q nitro_enclaves
RETURN=$?

set -e

# Setup Nitro enclave on the host if the module is available as expected.
if [ $RETURN -eq 0 ]; then
  amazon-linux-extras install aws-nitro-enclaves-cli -y
  yum install aws-nitro-enclaves-cli-devel -y
  usermod -aG ne ec2-user
  usermod -aG docker ec2-user
  # If needed, install custom allocator config here: /etc/nitro_enclaves/allocator.yaml
  systemctl start nitro-enclaves-allocator.service
  systemctl enable nitro-enclaves-allocator.service
  systemctl start docker
  systemctl enable docker
  #
  # Note: After some testing we discovered that there is an apparent bug in the
  # Nitro CLI RPM or underlying tools, that does not properly reload the
  # udev rules when inside the AWS bootstrap environment. This means that we must
  # manually fix the device permissions on `/dev/nitro_enclaves`, if we
  # don't want to be forced to restart the instance to get everything working.
  # See: https://github.com/aws/aws-nitro-enclaves-cli/issues/227
  #
  chgrp ne /dev/nitro_enclaves
  echo "Done with AWS Nitro enclave Setup"
fi

set -ex

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent

/etc/eks/bootstrap.sh ${CLUSTER_NAME} --b64-cluster-ca ${B64_CLUSTER_CA} --apiserver-endpoint ${API_SERVER_URL}

--==MYBOUNDARY==--\