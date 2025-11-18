# K3S Offline Installation Notes


## 1. Offline Install


### i. Show Environment


```shell
[root@localhost ~]# cat /etc/redhat-release 
Rocky Linux release 9.6 (Blue Onyx)
[root@localhost ~]# 


grubby --update-kernel ALL --args selinux=0
dnf remove -y selinux-policy selinux-policy-targeted
#reboot
```

### ii. Get Install Files (offline server)

- version v1.32.9+k3s1


```shell
 /usr/local/bin/k3s-uninstall.sh
```


```shell
wget https://github.com/k3s-io/k3s/releases/download/v1.32.9%2Bk3s1/k3s-airgap-images-amd64.tar
wget https://github.com/k3s-io/k3s/releases/download/v1.32.9%2Bk3s1/k3s
curl https://get.k3s.io > /opt/install.sh
```



### iii. Install K3S

- copy install file

```shell
mkdir -p /var/lib/rancher/k3s/agent/images/


scp xxyy:/tmp/k3s  /usr/local/bin/
scp xxyy:/tmp/k3s-airgap-images-amd64.tar  /var/lib/rancher/k3s/agent/images/
scp xxyy:/tmp/install.sh  /opt/


chmod  +x  /usr/local/bin/k3s
chmod  +x  /opt/install.sh 


[root@localhost ~]# k3s --version
k3s version v1.32.9+k3s1 (062b9534)
go version go1.23.12
[root@localhost ~]# 
```



```shell
INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC="--disable metrics-server --disable traefik"  /opt/install.sh
```




### iv. Verify K3S

```shell
[root@localhost ~]# export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


[root@localhost ~]# k3s kubectl get pod  -A 
NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-64fd4b4794-xwbhb                  1/1     Running   0          7s
kube-system   local-path-provisioner-774c6665dc-zth7w   1/1     Running   0          7s
[root@localhost ~]# 


[root@localhost ~]# kubectl get sc
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  4m49s
[root@localhost ~]# 
```



### v. Clean Environment (Uninstall)


```shell
/usr/local/bin/k3s-uninstall.sh
```

