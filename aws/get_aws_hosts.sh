#/bin/bash

# install the aws cli client first
# and run
# $> aws configure
# to set your keys (which you get from the AWS console)

# Remove existing lines from /etc/hosts
sed -i .bak '/# BEGIN AWS HOSTS/,/# END AWS HOSTS/d' /etc/hosts

# Get and put back AWS lines

printf "# BEGIN AWS HOSTS\n" >> /etc/hosts

for region in us-east-1 us-west-1 us-west-2
do

  aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[PublicIpAddress, Tags[?Key=='Name'].Value]" \
    --output text \
    --region=$region | perl -pe 's/(\.[0-9]+|None)\n/$1 /g' >> /etc/hosts

done

printf "# END AWS HOSTS\n" >> /etc/hosts
