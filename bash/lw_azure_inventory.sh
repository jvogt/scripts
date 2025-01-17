#!/bin/bash
# Script to fetch Azure inventory for Lacework sizing.
# Requirements: az cli, jq

# This script can be run from Azure Cloud Shell.

# Set the initial counts to zero.
AZURE_VMS=0
SQL_SERVERS=0
LOAD_BALANCERS=0
GATEWAYS=0

function getResourceGroups {
  az group list | jq -r '.[] | .name'
}

function getVMs {
  az vm list -d --query "[?powerState=='VM running']" | jq length
}

function getSQLServers {
  az sql server list | jq length
}

function getLoadBalancers {
  az network lb list | jq length
}

function getGateways {
  RG=$1
  az network vnet-gateway list --resource-group $RG | jq length
}

function getSubscriptions {
  az account list | jq -r '.[] | .id'
}

originalsub=$(az account show | jq -r '.id')

echo "Starting inventory check."
echo "Iterating over subscriptions visible to this user"
subs=$(getSubscriptions)

for s in $subs; do
  az account set --subscription $s
  echo "Fetching VMs... in subscription " $s
  vms=$(getVMs)
  AZURE_VMS=$(($AZURE_VMS + $vms))

  echo "Fetching SQL Databases... in subscription " $s
  sql=$(getSQLServers)
  SQL_SERVERS=$(($SQL_SERVERS + $sql))

  echo "Fetching Load Balancers... in subscription " $s
  lbs=$(getLoadBalancers)
  LOAD_BALANCERS=$(($LOAD_BALANCERS + $lbs))

  echo "Fetching Gateways... in subscription " $s
  for group in $(getResourceGroups); do
    gw=$(getGateways $group)
    GATEWAYS=$(($GATEWAYS + $gw))
  done
done

echo "Setting back original subscription into AZ CLI context"
az account set --subscription $originalsub

echo "######################################################################"
echo "Lacework inventory collection complete."
echo ""
echo "Azure VMs:         $AZURE_VMS"
echo "SQL Servers:       $SQL_SERVERS"
echo "Load Balancers:    $LOAD_BALANCERS"
echo "Vnet Gateways:     $GATEWAYS"
echo "===================="
echo "Total Resources:   $(($AZURE_VMS + $SQL_SERVERS + $LOAD_BALANCERS + $GATEWAYS))"

