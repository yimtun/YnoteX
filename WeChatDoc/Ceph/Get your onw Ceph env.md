# Get your onw Ceph env



Hi everyone, my name is Michael, and I'm a developer. I'm currently practicing my English writing.




In the past, software was all-in-one, including both physical and software parts. As a developer, you had to install and prepare the system, hardware drivers, configure hardware network devices or set route rules directly on the system, build your own web server, configure SSL certificates, and so on.


But later, like other industries, the software field also had specialization and pipeline like Ford."We started building distributed systems – a big system running across many physical machines, VMs, or bare containers.
So, we got different roles: infra engineer, DB engineer, network engineer, system engineer, backend engineer, frontend engineer. You only needed to write your business code. You didn't need to care about other things. If there was trouble, you could just search the monitoring / APM system, and look at system load, JVM usage, and logs.



Then, Kubernetes came. Logically, it's a distributed system, but physically, it's back to all-in-one. A K8s node takes on more tasks – networking, storage, and more.


This is a trend – things are coming back. With K8s, many functions have returned to the system level. As a developer, you have to know everything again. Especially as an Infra Developer, it's about virtualization technologies: KVM, libvirt, OpenStack, Kubernetes.


If you just use public cloud for VMs, you don't need to know how to use a block device. But now, for a pod, you have to know how it works. Networking is also more complicated – not just static routes, but many kernel-supported network functions.


So, I think I can pull some English docs together. This can improve my English writing and maybe be useful to you too.


This time, this doc will show you how to set up a basic Ceph environment without needing many disk devices.If there are some errors in the tech or my English, I'd really appreciate your feedback.




A quick note on my approach: My documentation isn't heavily focused on theory. One reason is that I want to keep my English writing fairly conversational. The other, more important reason, is that I prefer to get things working first. Once you have a running environment, you can then explore the concepts and theory behind it on your own.


OK, let's go!



## 1. Show You My Env

```shell
[root@10-211-55-34 ~]# systemctl  disable --now firewalld
[root@10-211-55-34 ~]# setenforce 0
setenforce: SELinux is disabled
[root@10-211-55-34 ~]# 
[root@10-211-55-34 ~]# cat /etc/redhat-release 
Rocky Linux release 9.6 (Blue Onyx)
[root@10-211-55-34 ~]# uname -r
6.17.4-1.el9.elrepo.x86_64
[root@10-211-55-34 ~]# hostname
10-211-55-34
[root@10-211-55-34 ~]# 
```

## 2. Prepare cephadm  And  Devices



```shell
curl -L --remote-name https://download.ceph.com/rpm-reef/el9/noarch/cephadm
install -m 755 cephadm /usr/sbin/cephadm
```

```shell
[root@10-211-55-34 ~]# cephadm version
cephadm version 18.2.7 (6b0e988052ec84cf2d4a54ff9bbbc5e720b621ad) reef (stable)
```


create 3 disks for Ceph and use  losetup mount system

```shell
[root@10-211-55-34 ~]# mkdir -p /ceph-disks
[root@10-211-55-34 ~]# dd if=/dev/zero of=/ceph-disks/osd0.img bs=1M count=10240
[root@10-211-55-34 ~]# dd if=/dev/zero of=/ceph-disks/osd1.img bs=1M count=10240
[root@10-211-55-34 ~]# dd if=/dev/zero of=/ceph-disks/osd2.img bs=1M count=10240



[root@10-211-55-34 ~]# losetup -fP /ceph-disks/osd0.img
[root@10-211-55-34 ~]# losetup -fP /ceph-disks/osd1.img
[root@10-211-55-34 ~]# losetup -fP /ceph-disks/osd2.img
[root@10-211-55-34 ~]# losetup  -a
/dev/loop1: [64768]:319204 (/ceph-disks/osd1.img)
/dev/loop2: [64768]:319207 (/ceph-disks/osd2.img)
/dev/loop0: [64768]:319201 (/ceph-disks/osd0.img)
[root@10-211-55-34 ~]# 



# create pv vg and lv for 3 disks
[root@10-211-55-34 ~]# pvcreate /dev/loop0
  Physical volume "/dev/loop0" successfully created.
[root@10-211-55-34 ~]# pvcreate /dev/loop1
  Physical volume "/dev/loop1" successfully created.
[root@10-211-55-34 ~]# pvcreate /dev/loop2
  Physical volume "/dev/loop2" successfully created.
[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]# vgcreate ceph-vg0 /dev/loop0
  Volume group "ceph-vg0" successfully created
[root@10-211-55-34 ~]# vgcreate ceph-vg1 /dev/loop1
  Volume group "ceph-vg1" successfully created
[root@10-211-55-34 ~]# vgcreate ceph-vg2 /dev/loop2
  Volume group "ceph-vg2" successfully created
[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]# lvcreate -n osd-lv0 -l 100%FREE ceph-vg0
  Logical volume "osd-lv0" created.
[root@10-211-55-34 ~]# lvcreate -n osd-lv1 -l 100%FREE ceph-vg1
  Logical volume "osd-lv1" created.
[root@10-211-55-34 ~]# lvcreate -n osd-lv2 -l 100%FREE ceph-vg2
  Logical volume "osd-lv2" created.
[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]# lvs
  LV      VG       Attr       LSize    Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  osd-lv0 ceph-vg0 -wi-a-----  <10.00g                                                    
  osd-lv1 ceph-vg1 -wi-------  <10.00g                                                    
  osd-lv2 ceph-vg2 -wi-a-----  <10.00g            
```




```shell  aoto mount and active lvm 
[root@10-211-55-34 ~]# cat  /etc/rc.d/rc.local
#!/bin/bash
# THIS FILE IS ADDED FOR COMPATIBILITY PURPOSES
#
# It is highly advisable to create own systemd services or udev rules
# to run scripts during boot instead of using this file.
#
# In contrast to previous versions due to parallel execution during boot
# this script will NOT be run after all other services.
#
# Please note that you must run 'chmod +x /etc/rc.d/rc.local' to ensure
# that this script will be executed during boot.


losetup -fP /ceph-disks/osd0.img
losetup -fP /ceph-disks/osd1.img
losetup -fP /ceph-disks/osd2.img
lvchange  -ay ceph-vg0/osd-lv0
lvchange  -ay ceph-vg1/osd-lv1
lvchange  -ay ceph-vg2/osd-lv2
touch /var/lock/subsys/local

[root@10-211-55-34 ~]# 
[root@10-211-55-34 ~]# chmod  +x /etc/rc.d/rc.local 
[root@10-211-55-34 ~]# 
```

you cant reboot you system to verify disk if can use  like this:

```shell
[root@10-211-55-34 ~]# lvs
  LV      VG       Attr       LSize    Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  osd-lv0 ceph-vg0 -wi-ao----  <10.00g                                                    
  osd-lv1 ceph-vg1 -wi-ao----  <10.00g                                                    
  osd-lv2 ceph-vg2 -wi-ao----  <10.00g                                                    
  root    rl       -wi-ao---- <199.00g                                                    
[root@10-211-55-34 ~]# 
```



## 3. Start To Deploy


```shell
[root@10-211-55-34 ~]# cephadm bootstrap --mon-ip 10.211.55.34 --initial-dashboard-user admin --initial-dashboard-password admin123

[root@10-211-55-34 ~]# cephadm shell -- ceph config set global osd_pool_default_size 1
[root@10-211-55-34 ~]# cephadm shell -- ceph config set global osd_pool_default_min_size 1


[root@10-211-55-34 ~]#  cephadm shell -- ceph config get mon osd_pool_default_min_size
Inferring fsid 7437895a-b2df-11f0-b037-001c4277e7e6
Inferring config /var/lib/ceph/7437895a-b2df-11f0-b037-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
1
[root@10-211-55-34 ~]# cephadm shell -- ceph config get mon osd_pool_default_size
Inferring fsid 7437895a-b2df-11f0-b037-001c4277e7e6
Inferring config /var/lib/ceph/7437895a-b2df-11f0-b037-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
1
[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]# cephadm shell -- ceph orch daemon add osd 10-211-55-34:/dev/ceph-vg0/osd-lv0
[root@10-211-55-34 ~]# cephadm shell -- ceph orch daemon add osd 10-211-55-34:/dev/ceph-vg1/osd-lv1
[root@10-211-55-34 ~]# cephadm shell -- ceph orch daemon add osd 10-211-55-34:/dev/ceph-vg2/osd-lv2


[root@10-211-55-34 ~]# cephadm shell  -- ceph -s
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
  cluster:
    id:     a9ae839a-b325-11f0-9192-001c4277e7e6
    health: HEALTH_WARN
            1 pool(s) have no replicas configured
 
  services:
    mon: 1 daemons, quorum 10-211-55-34 (age 14m)
    mgr: 10-211-55-34.tyovqz(active, since 12m)
    osd: 3 osds: 3 up (since 21s), 3 in (since 41s)
 
  data:
    pools:   1 pools, 1 pgs
    objects: 2 objects, 577 KiB
    usage:   80 MiB used, 30 GiB / 30 GiB avail
    pgs:     1 active+clean
 
[root@10-211-55-34 ~]#  


[root@10-211-55-34 ~]# cephadm shell -- ceph osd tree
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.02939  root default                                    
-3         0.02939      host 10-211-55-34                           
 0    ssd  0.00980          osd.0              up   1.00000  1.00000
 1    ssd  0.00980          osd.1              up   1.00000  1.00000
 2    ssd  0.00980          osd.2              up   1.00000  1.00000
[root@10-211-55-34 ~]# 





[root@10-211-55-34 ~]#  cephadm shell -- ceph osd pool ls detail
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
pool 1 '.mgr' replicated size 1 min_size 1 crush_rule 0 object_hash rjenkins pg_num 1 pgp_num 1 autoscale_mode on last_change 12 flags hashpspool stripe_width 0 pg_num_max 32 pg_num_min 1 application mgr read_balance_score 3.03

[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]#  cephadm shell -- ceph osd lspools
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
1 .mgr
[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]# cephadm shell  -- ceph -s



# create your test pool
[root@10-211-55-34 ~]# cephadm shell -- ceph osd pool create testpool 16 16
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
pool 'testpool' created
[root@10-211-55-34 ~]# 

[root@10-211-55-34 ~]# cephadm shell -- ceph osd pool application enable testpool rbd
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
enabled application 'rbd' on pool 'testpool'
[root@10-211-55-34 ~]# 



# create  another pool rbd
[root@10-211-55-34 ~]# cephadm shell -- ceph osd pool create  rbd 16 16
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
pool 'rbd' created
[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]# cephadm shell -- ceph osd pool application enable rbd rbd
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
enabled application 'rbd' on pool 'rbd'
[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]# cephadm shell  -- ceph -s
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
  cluster:
    id:     a9ae839a-b325-11f0-9192-001c4277e7e6
    health: HEALTH_WARN
            3 pool(s) have no replicas configured
 
  services:
    mon: 1 daemons, quorum 10-211-55-34 (age 20m)
    mgr: 10-211-55-34.tyovqz(active, since 18m)
    osd: 3 osds: 3 up (since 6m), 3 in (since 6m)
 
  data:
    pools:   3 pools, 33 pgs
    objects: 2 objects, 577 KiB
    usage:   80 MiB used, 30 GiB / 30 GiB avail
    pgs:     33 active+clean
 
[root@10-211-55-34 ~]# 
```


### carete  a test block device


```shell
[root@10-211-55-34 ~]# cephadm shell  -- rbd create testimage --size 1024 --pool testpool
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
[root@10-211-55-34 ~]# 
```


### create a user 


```shell
[root@10-211-55-34 ~]# cephadm shell -- ceph auth get-or-create client.testUser mon 'profile rbd' osd 'profile rbd pool=testpool' mgr 'profile rbd pool=testpool'
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
[client.testUser]
        key = AQCK6/5oPu1UHBAAPe0/GBHsDEx3/GtK5gEfXw==
[root@10-211-55-34 ~]# 
```



## 4. System As Rbd Client

###  user  nbd map

```shell
[root@10-211-55-32 ~]# dnf install https://dl.rockylinux.org/pub/rocky/9.6/extras/x86_64/os/Packages/c/centos-release-ceph-pacific-1.0-2.el9.noarch.rpm
[root@10-211-55-35 ~]# dnf  install   -y  rbd-nbd
[root@10-211-55-35 ~]# rbd-nbd  --version
ceph version 16.2.15 (618f440892089921c3e944a991122ddc44e60516) pacific (stable)
[root@10-211-55-35 ~]# 

rbd-nbd map testpool/testimage  


[root@10-211-55-35 ~]# rbd-nbd map testpool/testimage --id testUser --key AQCK6/5oPu1UHBAAPe0/GBHsDEx3/GtK5gEfXw== --mon-host 10.211.55.34:6789
did not load config file, using default settings.
2025-10-27T11:52:59.366+0800 7ff7b0e2f680 -1 Errors while parsing config file!

2025-10-27T11:52:59.366+0800 7ff7b0e2f680 -1 can't open ceph.conf: (2) No such file or directory

2025-10-27T11:52:59.400+0800 7ff7b0e2f680 -1 Errors while parsing config file!

2025-10-27T11:52:59.400+0800 7ff7b0e2f680 -1 can't open ceph.conf: (2) No such file or directory

/dev/nbd0
[root@10-211-55-35 ~]# 


[root@10-211-55-35 ~]# lsblk /dev/nbd0
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
nbd0  43:0    0   1G  0 disk 
[root@10-211-55-35 ~]# 


[root@10-211-55-35 ~]# mkfs.xfs  /dev/nbd0
meta-data=/dev/nbd0              isize=512    agcount=4, agsize=65536 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=0
data     =                       bsize=4096   blocks=262144, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=16384, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
Discarding blocks...Done.
[root@10-211-55-35 ~]# 

[root@10-211-55-35 ~]# mkdir /testMountNbd
[root@10-211-55-35 ~]# mount  /dev/nbd0  /testMountNbd/
[root@10-211-55-35 ~]# 

[root@10-211-55-35 ~]# df  -lh
Filesystem           Size  Used Avail Use% Mounted on
devtmpfs             3.8G     0  3.8G   0% /dev
tmpfs                3.8G     0  3.8G   0% /dev/shm
tmpfs                1.5G   10M  1.5G   1% /run
/dev/mapper/rl-root  199G   40G  160G  21% /
/dev/sda1            960M  432M  529M  45% /boot
tmpfs                768M  8.0K  768M   1% /run/user/0
/dev/nbd0            960M   39M  922M   5% /testMountNbd

[root@10-211-55-35 ~]# umount  /testMountNbd/
[root@10-211-55-35 ~]# 
```



### kernel rbd Client 

```shell
[root@10-211-55-32 ~]# dnf install https://dl.rockylinux.org/pub/rocky/9.6/extras/x86_64/os/Packages/c/centos-release-ceph-pacific-1.0-2.el9.noarch.rpm
[root@10-211-55-32 ~]# dnf install   -y ceph-common
[root@10-211-55-32 ~]# rbd --version
ceph version 16.2.15 (618f440892089921c3e944a991122ddc44e60516) pacific (stable)
[root@10-211-55-32 ~]# 


[root@10-211-55-35 ~]#  rbd map testpool/testimage --id testUser --key AQCK6/5oPu1UHBAAPe0/GBHsDEx3/GtK5gEfXw== --mon-host 10.211.55.34:6789
did not load config file, using default settings.
2025-10-27T12:02:43.687+0800 7fe977635a00 -1 Errors while parsing config file!

2025-10-27T12:02:43.687+0800 7fe977635a00 -1 can't open ceph.conf: (2) No such file or directory

2025-10-27T12:02:43.688+0800 7fe977635a00 -1 Errors while parsing config file!

2025-10-27T12:02:43.688+0800 7fe977635a00 -1 can't open ceph.conf: (2) No such file or directory

/dev/rbd0
[root@10-211-55-35 ~]# 

[root@10-211-55-35 ~]# mkdir /testMountRbd
[root@10-211-55-35 ~]# mount /dev/rbd0 /testMountRbd/
[root@10-211-55-35 ~]# df -lh
Filesystem           Size  Used Avail Use% Mounted on
devtmpfs             3.8G     0  3.8G   0% /dev
tmpfs                3.8G     0  3.8G   0% /dev/shm
tmpfs                1.5G   10M  1.5G   1% /run
/dev/mapper/rl-root  199G   40G  160G  21% /
/dev/sda1            960M  432M  529M  45% /boot
tmpfs                768M  8.0K  768M   1% /run/user/0
/dev/rbd0            960M   39M  922M   5% /testMountRbd
[root@10-211-55-35 ~]# 
[root@10-211-55-35 ~]# umount  /testMountRbd/
```



## 5. Docker As Client

```shell
[root@10-211-55-35 ~]# dnf -y remove rbd-nbd ceph-common

[root@10-211-55-35 ~]# find /lib/modules/$(uname -r) -name "*rbd*"
/lib/modules/6.17.4-1.el9.elrepo.x86_64/kernel/drivers/block/drbd
/lib/modules/6.17.4-1.el9.elrepo.x86_64/kernel/drivers/block/drbd/drbd.ko.xz
/lib/modules/6.17.4-1.el9.elrepo.x86_64/kernel/drivers/block/rbd.ko.xz
[root@10-211-55-35 ~]# find /lib/modules/$(uname -r) -name "*nbd*"
/lib/modules/6.17.4-1.el9.elrepo.x86_64/kernel/drivers/block/nbd.ko.xz
[root@10-211-55-35 ~]# 



[root@10-211-55-35 ~]# dnf -y remove  dkms



[root@10-211-55-35 ~]#  modinfo rbd
filename:       /lib/modules/6.17.4-1.el9.elrepo.x86_64/kernel/drivers/block/rbd.ko.xz
license:        GPL
description:    RADOS Block Device (RBD) driver
author:         Jeff Garzik <jeff@garzik.org>
author:         Yehuda Sadeh <yehuda@hq.newdream.net>
author:         Sage Weil <sage@newdream.net>
author:         Alex Elder <elder@inktank.com>
srcversion:     650224E22C5F5BF2EFB2B05
depends:        libceph
intree:         Y
name:           rbd
retpoline:      Y
vermagic:       6.17.4-1.el9.elrepo.x86_64 SMP preempt mod_unload modversions 
parm:           single_major:Use a single major number for all rbd devices (default: true) (bool)
[root@10-211-55-35 ~]# 




## nbd
[root@10-211-55-35 ~]# docker run --rm -it --net=host -v /etc/ceph:/etc/ceph:ro -v /lib/modules:/lib/modules:ro -v /dev:/dev --privileged quay.io/ceph/ceph:v18 bash
[root@10-211-55-35 /]# rbd-nbd map testpool/testimage --id testUser --key AQCK6/5oPu1UHBAAPe0/GBHsDEx3/GtK5gEfXw== --mon-host 10.211.55.34:6789
did not load config file, using default settings.
2025-10-27T05:42:19.748+0000 7f4787c31980 -1 Errors while parsing config file!
2025-10-27T05:42:19.748+0000 7f4787c31980 -1 can't open ceph.conf: (2) No such file or directory
2025-10-27T05:42:19.815+0000 7f4787c31980 -1 Errors while parsing config file!
2025-10-27T05:42:19.815+0000 7f4787c31980 -1 can't open ceph.conf: (2) No such file or directory
/dev/nbd0
[root@10-211-55-35 /]# 

[root@10-211-55-35 /]# rbd-nbd  list-mapped  --id testUser --key AQCK6/5oPu1UHBAAPe0/GBHsDEx3/GtK5gEfXw== --mon-host 10.211.55.34:6789


[root@10-211-55-35 /]# mount /dev/nbd0 /tmp/
[root@10-211-55-35 /]# df -lh
Filesystem           Size  Used Avail Use% Mounted on
overlay              199G   40G  160G  20% /
devtmpfs             3.8G     0  3.8G   0% /dev
tmpfs                3.8G     0  3.8G   0% /dev/shm
/dev/mapper/rl-root  199G   40G  160G  20% /etc/ceph
/dev/nbd0            960M   39M  922M   5% /tmp
[root@10-211-55-35 /]# 
[root@10-211-55-35 /]# umount /tmp/
[root@10-211-55-35 /]# 


# rbd

[root@10-211-55-35 ~]# docker run --rm -it --net=host -v /etc/ceph:/etc/ceph:ro -v /lib/modules:/lib/modules:ro -v /dev:/dev --privileged quay.io/ceph/ceph:v18 bash

[root@10-211-55-35 /]# rbd map testpool/testimage --id testUser --key AQCK6/5oPu1UHBAAPe0/GBHsDEx3/GtK5gEfXw== --mon-host 10.211.55.34:6789
did not load config file, using default settings.
2025-10-27T05:47:22.871+0000 7f73b36a5d00 -1 Errors while parsing config file!
2025-10-27T05:47:22.871+0000 7f73b36a5d00 -1 can't open ceph.conf: (2) No such file or directory
2025-10-27T05:47:22.872+0000 7f73b36a5d00 -1 Errors while parsing config file!
2025-10-27T05:47:22.872+0000 7f73b36a5d00 -1 can't open ceph.conf: (2) No such file or directory

/dev/rbd0

[root@10-211-55-35 /]# rbd showmapped  --id testUser --key AQCK6/5oPu1UHBAAPe0/GBHsDEx3/GtK5gEfXw== --mon-host 10.211.55.34:6789did not load config file, using default settings.
2025-10-27T05:51:17.926+0000 7efdb9b92d00 -1 Errors while parsing config file!
2025-10-27T05:51:17.926+0000 7efdb9b92d00 -1 can't open ceph.conf: (2) No such file or directory
2025-10-27T05:51:17.926+0000 7efdb9b92d00 -1 Errors while parsing config file!
2025-10-27T05:51:17.926+0000 7efdb9b92d00 -1 can't open ceph.conf: (2) No such file or directory
id  pool      namespace  image      snap  device   
0   testpool             testimage  -     /dev/rbd0
[root@10-211-55-35 /]# 

[root@10-211-55-35 /]# 
[root@10-211-55-35 /]# mount /dev/rbd0  /tmp/
[root@10-211-55-35 /]# df -lh
Filesystem           Size  Used Avail Use% Mounted on
overlay              199G   40G  160G  20% /
devtmpfs             3.8G     0  3.8G   0% /dev
tmpfs                3.8G     0  3.8G   0% /dev/shm
/dev/mapper/rl-root  199G   40G  160G  20% /etc/ceph
/dev/rbd0            960M   39M  922M   5% /tmp
[root@10-211-55-35 /]# umount /tmp/
[root@10-211-55-35 /]# 

[root@10-211-55-35 /]# rbd unmap testpool/testimage --id testUser --key AQCK6/5oPu1UHBAAPe0/GBHsDEx3/GtK5gEfXw== --mon-host 10.211.55.34:6789
did not load config file, using default settings.
2025-10-27T05:48:40.432+0000 7f776d6b4d00 -1 Errors while parsing config file!
2025-10-27T05:48:40.432+0000 7f776d6b4d00 -1 can't open ceph.conf: (2) No such file or directory
2025-10-27T05:48:40.433+0000 7f776d6b4d00 -1 Errors while parsing config file!
2025-10-27T05:48:40.433+0000 7f776d6b4d00 -1 can't open ceph.conf: (2) No such file or directory
[root@10-211-55-35 /]# echo $?
0
[root@10-211-55-35 /]# 
```



## 6. Pod's Volume As client 


- direct use rbd don't use pv pvc 


```shell
[root@10-211-55-34 ceph]#  cephadm shell -- rbd create  rbd-device01 --size 1024 --pool  rbd
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
[root@10-211-55-34 ceph]# 

[root@10-211-55-32 etc]# kubectl delete secret ceph-secret
secret "ceph-secret" deleted
[root@10-211-55-32 etc]# kubectl create secret generic ceph-secret \
--type="kubernetes.io/rbd" \
--from-literal=key=AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ== \
--namespace=default
secret/ceph-secret created
[root@10-211-55-32 etc]# 


[root@10-211-55-32 ~]# kubectl delete pod direct-rbd-pod --force --grace-period=0
[root@10-211-55-32 ~]# cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: direct-rbd-pod
spec:
  containers:
  - name: app
    image: yimtune/nginx:1.21.6
    volumeMounts:
    - mountPath: /data
      name: ceph-rbd-data
  volumes:
  - name: ceph-rbd-data
    rbd:
      monitors:
      - 10.211.55.34:6789
      pool: rbd
      image: rbd-device01
      fsType: ext4
      readOnly: false
      user: admin
      secretRef:
        name: ceph-secret
EOF
pod/direct-rbd-pod created




[root@10-211-55-32 ~]# kubectl  exec -it direct-rbd-pod  -- ls /data/
lost+found
[root@10-211-55-32 ~]# kubectl exec -it direct-rbd-pod -- df -h /data
Filesystem      Size  Used Avail Use% Mounted on
/dev/rbd0       974M   24K  958M   1% /data
[root@10-211-55-32 ~]# 



[root@10-211-55-32 ~]# kubectl delete pod direct-rbd-pod --force --grace-period=0
[root@10-211-55-32 ~]# kubectl delete secret ceph-secret
[root@10-211-55-34 ceph]# cephadm shell -- rbd rm rbd-device01 --pool rbd
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
Removing image: 100% complete...done.
[root@10-211-55-34 ceph]# 
```


##  7. PersistentVolume  As Client



```shell
[root@10-211-55-32 etc]# kubectl delete secret ceph-secret
secret "ceph-secret" deleted
[root@10-211-55-32 etc]# kubectl create secret generic ceph-secret \
--type="kubernetes.io/rbd" \
--from-literal=key=AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ== \
--namespace=default
secret/ceph-secret created
[root@10-211-55-32 etc]# 
```


```shell
[root@10-211-55-34 ceph]# cephadm shell  -- rbd create myapp-data --size 1024 --pool rbd
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
[root@10-211-55-34 ceph]# 
```


```shell
[root@10-211-55-32 ~]# kubectl  delete  pod testpv
pod "testpv" deleted
[root@10-211-55-32 ~]# 
[root@10-211-55-32 ~]# kubectl  delete pvc pvc1
persistentvolumeclaim "pvc1" deleted
[root@10-211-55-32 ~]# 
[root@10-211-55-32 ~]# kubectl  delete pv   ceph-rbd-pv-complete
persistentvolume "ceph-rbd-pv-complete" deleted
[root@10-211-55-32 ~]# 
```


```shell
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ceph-rbd-pv-complete
  labels:
    type: ceph-rbd
    app: nginx
    pv-name: ceph-rbd-pv-complete
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  rbd:
    monitors:
      - 10.211.55.34:6789
    pool: rbd
    image: myapp-data
    fsType: ext4
    readOnly: false
    user: admin
    secretRef:
      name: ceph-secret
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc1
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  selector:
    matchLabels:
      app: nginx  # 这个标签在 PV 中存在，应该能匹配
  storageClassName: ""
---
apiVersion: v1
kind: Pod
metadata:
  name: testpv
spec:
  containers:
  - name: vp1  # 建议使用更具描述性的名称，如 nginx-container
    image: yimtune/nginx:1.21.6
    volumeMounts:
    - name: ceph-rbd-data
      mountPath: /data
  volumes:
  - name: ceph-rbd-data
    persistentVolumeClaim:
      claimName: pvc1
EOF
```



```shell
[root@10-211-55-32 ~]# kubectl  get pvc pvc1
NAME   STATUS   VOLUME                 CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc1   Bound    ceph-rbd-pv-complete   1Gi        RWO                           21s
[root@10-211-55-32 ~]# kubectl  get pv ceph-rbd-pv-complete
NAME                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM          STORAGECLASS   REASON   AGE
ceph-rbd-pv-complete   1Gi        RWO            Retain           Bound    default/pvc1                           27s
[root@10-211-55-32 ~]# 
```



```shell
[root@10-211-55-32 ~]# kubectl exec -it  testpv -- df -h /data
Filesystem      Size  Used Avail Use% Mounted on
/dev/rbd0       974M   24K  958M   1% /data
[root@10-211-55-32 ~]# 



[root@10-211-55-32 ~]# kubectl  delete  pod testpv
pod "testpv" deleted
[root@10-211-55-32 ~]# kubectl  delete pvc pvc1
persistentvolumeclaim "pvc1" deleted
[root@10-211-55-32 ~]# kubectl  delete pv   ceph-rbd-pv-complete
persistentvolume "ceph-rbd-pv-complete" deleted
[root@10-211-55-32 ~]# kubectl delete secret ceph-secret
secret "ceph-secret" deleted
[root@10-211-55-32 ~]# 
```


```shell
[root@10-211-55-34 ceph]# cephadm shell -- rbd rm myapp-data --pool rbd
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
Removing image: 100% complete...done.
[root@10-211-55-34 ceph]# 

```

## 8. Deployment Use Static PersistentVolume 



- Static PersistentVolume  is  direct Ceph CLient


```shell
[root@10-211-55-34 ceph]# cephadm shell  -- rbd create deploy-rbd --size 1024 --pool rbd
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
[root@10-211-55-34 ceph]# 
```

```shell
[root@10-211-55-32 ~]# kubectl delete secret ceph-secret
Error from server (NotFound): secrets "ceph-secret" not found
[root@10-211-55-32 ~]# kubectl create secret generic ceph-secret \
--type="kubernetes.io/rbd" \
--from-literal=key=AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ== \
--namespace=default
secret/ceph-secret created
[root@10-211-55-32 ~]# 
```


```shell
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ceph-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  rbd:
    monitors:
      - 10.211.55.34:6789
    pool: rbd
    image: deploy-rbd
    user: admin
    secretRef:
      name: ceph-secret
---    
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""   # 注意这里要空字符串
  volumeName: ceph-pv
EOF
```


```shell
[root@10-211-55-32 ~]# kubectl  get pvc  ceph-vpc
Error from server (NotFound): persistentvolumeclaims "ceph-vpc" not found
[root@10-211-55-32 ~]# kubectl  get pvc  ceph-pvc
NAME       STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
ceph-pvc   Bound    ceph-pv   1Gi        RWO                           17s
[root@10-211-55-32 ~]# kubectl  get pv ceph-pv
NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM              STORAGECLASS   REASON   AGE
ceph-pv   1Gi        RWO            Retain           Bound    default/ceph-pvc                           29s
[root@10-211-55-32 ~]# 
```

```shell
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ceph
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-ceph
  template:
    metadata:
      labels:
        app: nginx-ceph
    spec:
      containers:
      - name: nginx
        image: yimtune/nginx:1.21.6
        ports:
        - containerPort: 80
        volumeMounts:
        - name: ceph-storage
          mountPath: /usr/share/nginx/html
      volumes:
      - name: ceph-storage
        persistentVolumeClaim:
          claimName: ceph-pvc
EOF
```

```shell
[root@10-211-55-32 ~]# kubectl  get deployment nginx-ceph
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
nginx-ceph   1/1     1            1           10s
[root@10-211-55-32 ~]# 
```


```shell
[root@10-211-55-32 ~]# kubectl  exec -it nginx-ceph-755666c59-tzdhn -- df -lh
Filesystem      Size  Used Avail Use% Mounted on
overlay         149G   22G  128G  15% /
tmpfs            64M     0   64M   0% /dev
shm              64M     0   64M   0% /dev/shm
/dev/sda2       149G   22G  128G  15% /etc/hosts
/dev/rbd0       974M   24K  958M   1% /usr/share/nginx/html
tmpfs            16G   12K   16G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs           7.7G     0  7.7G   0% /proc/acpi
tmpfs           7.7G     0  7.7G   0% /proc/scsi
tmpfs           7.7G     0  7.7G   0% /sys/firmware
[root@10-211-55-32 ~]# 
```



```shell
[root@10-211-55-32 ~]# kubectl  delete deployment nginx-ceph
deployment.apps "nginx-ceph" deleted
[root@10-211-55-32 ~]# 

[root@10-211-55-32 ~]# kubectl  delete pvc ceph-pvc
persistentvolumeclaim "ceph-pvc" deleted
[root@10-211-55-32 ~]# 

[root@10-211-55-32 ~]# kubectl  delete pv ceph-pv
persistentvolume "ceph-pv" deleted
[root@10-211-55-32 ~]# 

[root@10-211-55-34 ceph]# cephadm shell  -- rbd rm deploy-rbd  --pool rbd
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
Removing image: 100% complete...done.
[root@10-211-55-34 ceph]# 



[root@10-211-55-32 ~]# kubectl  delete secret ceph-secret
secret "ceph-secret" deleted
[root@10-211-55-32 ~]# 
```



## 9. Ceph CSI as Client



- version: cephcsi:v3.12.0



get auth config:  user name ,key ,fsid 

```shell
[root@10-211-55-34 ceph]# cephadm shell -- ceph auth get client.admin
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
[client.admin]
        key = AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==
        caps mds = "allow *"
        caps mgr = "allow *"
        caps mon = "allow *"
        caps osd = "allow *"
[root@10-211-55-34 ceph]# 


[root@10-211-55-34 ceph]# cephadm shell -- ceph fsid
Inferring fsid a9ae839a-b325-11f0-9192-001c4277e7e6
Inferring config /var/lib/ceph/a9ae839a-b325-11f0-9192-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
a9ae839a-b325-11f0-9192-001c4277e7e6
[root@10-211-55-34 ceph]# 
```


```shell
[root@10-211-55-32 ~]# kubectl  delete pvc pvc1
persistentvolumeclaim "pvc1" deleted
[root@10-211-55-32 ~]# kubectl  delete sc sc1
storageclass.storage.k8s.io "sc1" deleted
[root@10-211-55-32 ~]# 

[root@10-211-55-32 ~]# helm uninstall ceph-csi-rbd
release "ceph-csi-rbd" uninstalled
[root@10-211-55-32 ~]# 

[root@10-211-55-32 ~]# kubectl  delete secret csi-rbd-node-secret
secret "csi-rbd-node-secret" deleted
[root@10-211-55-32 ~]# 


```

- test auth

```shell
[root@10-211-55-32 ~]# rados lspools -p rbd --id admin --key AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ== --mon-host 10.211.55.34:6789
.mgr
testpool
rbd
[root@10-211-55-32 ~]# 
```



```shell
[root@10-211-55-32 ~]# cat /root/values.yaml
# values.yaml
clusterID: "a9ae839a-b325-11f0-9192-001c4277e7e6"
monitors:
  - "10.211.55.34:6789"

provisioner:
  replicaCount: 1

nodeplugin:
  replicaCount: 1


secret:
  create: true
  name: csi-rbd-secret
  userId: admin
  userKey: "AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ=="

nodeSecret:
  create: true
  name: csi-rbd-node-secret
  userId: admin
  userKey: "AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ=="


# 禁用加密
encryption:
  enabled: false
[root@10-211-55-32 ~]# 
```


```shell
[root@10-211-55-32 ~]# helm  uninstall ceph-csi-rbd
release "ceph-csi-rbd" uninstalled
[root@10-211-55-32 ~]# 
[root@10-211-55-32 ~]# helm  install ceph-csi-rbd ceph-csi/ceph-csi-rbd --version 3.12.0 --namespace default -f /root/values.yaml
NAME: ceph-csi-rbd
LAST DEPLOYED: Mon Oct 27 19:27:22 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Examples on how to configure a storage class and start using the driver are here:
https://github.com/ceph/ceph-csi/tree/v3.12.0/examples/rbd
[root@10-211-55-32 ~]# 
```



```shell
[root@10-211-55-32 ~]# kubectl delete secret csi-rbd-secret -n default
secret "csi-rbd-secret" deleted
[root@10-211-55-32 ~]# kubectl create secret generic csi-rbd-secret -n default \
  --from-literal=userID=admin \
  --from-literal=userKey='AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==' \
  --from-literal=encryptionPassphrase='test_passphrase'
secret/csi-rbd-secret created
[root@10-211-55-32 ~]# 



=[root@10-211-55-32 ~]# kubectl create secret generic csi-rbd-node-secret -n default \
  --from-literal=userID=admin \
  --from-literal=userKey='AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ=='
secret/csi-rbd-node-secret created
[root@10-211-55-32 ~]# 
```


```shell
[root@10-211-55-32 ~]# kubectl -n default delete configmap ceph-csi-config
configmap "ceph-csi-config" deleted
[root@10-211-55-32 ~]# kubectl -n default create configmap ceph-csi-config \
  --from-literal=config.json='[
    {
      "clusterID": "a9ae839a-b325-11f0-9192-001c4277e7e6",
      "monitors": [
        "10.211.55.34:6789"
      ]
    }
  ]' \
  --from-literal=cluster-mapping.json='[
    {
      "clusterID": "a9ae839a-b325-11f0-9192-001c4277e7e6",
      "pool": "rbd"
    }
  ]'
configmap/ceph-csi-config created
[root@10-211-55-32 ~]# 
```


```shell
kubectl apply -f - <<EOF
apiVersion: v1
data:
  ceph.conf: |
    [global]
    fsid = a9ae839a-b325-11f0-9192-001c4277e7e6
    mon_host = 10.211.55.34
    auth_cluster_required = cephx
    auth_service_required = cephx
    auth_client_required = cephx
  keyring: |
    [client.admin]
    key = AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==
kind: ConfigMap
metadata:
  name: ceph-config
  namespace: default
EOF
```


```shell
[root@10-211-55-32 ~]# kubectl rollout restart deployment  ceph-csi-rbd-provisioner   -n default
deployment.apps/ceph-csi-rbd-provisioner restarted
[root@10-211-55-32 ~]# kubectl rollout restart daemonset ceph-csi-rbd-nodeplugin -n default
daemonset.apps/ceph-csi-rbd-nodeplugin restarted
[root@10-211-55-32 ~]# 
```


```shell
[root@10-211-55-32 ~]#  kubectl logs -f  $(kubectl get pod -l app=ceph-csi-rbd,component=nodeplugin -o jsonpath='{.items[0].metadata.name}') -c csi-rbdplugin
I1027 11:29:56.881675  161820 cephcsi.go:196] Driver version: v3.12.0 and Git version: 42797edd7e5e640e755a948a018d69c9200b7e60
E1027 11:29:56.881828  161820 cephcsi.go:272] Failed to get the PID limit, can not reconfigure: open /sys/fs/cgroup//pids.max: no such file or directory
I1027 11:29:56.881855  161820 cephcsi.go:228] Starting driver type: rbd with name: rbd.csi.ceph.com
I1027 11:29:56.893415  161820 topology.go:56] passed in node labels for processing: [failure-domain/region failure-domain/zone]
F1027 11:29:56.896942  161820 driver.go:145] missing domain labels [failure-domain/zone failure-domain/region] on node "10-211-55-32"
[root@10-211-55-32 ~]# 


[root@10-211-55-32 ~]# kubectl  label node 10-211-55-32  failure-domain/region=default
node/10-211-55-32 labeled
[root@10-211-55-32 ~]# kubectl  label node 10-211-55-32  failure-domain/zone=default
node/10-211-55-32 labeled
[root@10-211-55-32 ~]# 

[root@10-211-55-32 ~]# kubectl rollout restart daemonset ceph-csi-rbd-nodeplugin -n default
daemonset.apps/ceph-csi-rbd-nodeplugin restarted
[root@10-211-55-32 ~]# 
```






test config 

```shell
[root@10-211-55-32 ~]# kubectl exec -it $(kubectl get pod -l app=ceph-csi-rbd,component=nodeplugin -o jsonpath='{.items[0].metadata.name}') -c csi-rbdplugin -- rbd --pool rbd ls
testimage
[root@10-211-55-32 ~]# 


[root@10-211-55-32 ~]# kubectl exec -it $(kubectl get pod -l app=ceph-csi-rbd,component=provisioner -o jsonpath='{.items[0].metadata.name}')  -c csi-rbdplugin  -- rbd --pool rbd ls
testimage
[root@10-211-55-32 ~]# 
```





```shell
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sc1
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: a9ae839a-b325-11f0-9192-001c4277e7e6
  pool: rbd
  imageFormat: "2"
  csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
  csi.storage.k8s.io/provisioner-secret-namespace: default
  csi.storage.k8s.io/node-stage-secret-name: csi-rbd-node-secret
  csi.storage.k8s.io/node-stage-secret-namespace: default
  csi.storage.k8s.io/fstype: ext4
volumeBindingMode: Immediate
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
```


```shell
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc1
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: sc1
EOF
```



```shell
[root@10-211-55-32 ~]# kubectl  get pvc pvc1
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc1   Bound    pvc-7151f32b-a5f6-430f-9c65-ce016f280589   1Gi        RWO            sc1            4s
[root@10-211-55-32 ~]# kubectl  get sc sc1
NAME   PROVISIONER        RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc1    rbd.csi.ceph.com   Delete          Immediate           true                   15s
```



```shell
[root@10-211-55-32 ~]# kubectl  label node 10-211-55-32 topology.rbd.csi.ceph.com/region-
node/10-211-55-32 unlabeled
[root@10-211-55-32 ~]# kubectl  label node 10-211-55-32 topology.rbd.csi.ceph.com/zone-
node/10-211-55-32 unlabeled
[root@10-211-55-32 ~]# 
[root@10-211-55-32 ~]# kubectl  label node 10-211-55-32  failure-domain/region-
node/10-211-55-32 unlabeled
[root@10-211-55-32 ~]# kubectl  label node 10-211-55-32  failure-domain/zone-
node/10-211-55-32 unlabeled
[root@10-211-55-32 ~]# 



[root@10-211-55-32 ~]# helm  uninstall ceph-csi-rbd
release "ceph-csi-rbd" uninstalled
```




- secret backup 


```shell

[root@10-211-55-32 ~]# kubectl  get secret csi-rbd-secret -o yaml
apiVersion: v1
data:
  encryptionPassphrase: dGVzdF9wYXNzcGhyYXNl
  userID: YWRtaW4=
  userKey: QVFCYlUvOW9LWWJCREJBQTZQOWlzRVhXUDdWL08yU0g3N0lwbVE9PQ==
kind: Secret
metadata:
  creationTimestamp: "2025-10-27T11:28:08Z"
  name: csi-rbd-secret
  namespace: default
  resourceVersion: "878730"
  uid: c3f9dc56-ac2a-4512-b59e-23727d02ca47
type: Opaque
[root@10-211-55-32 ~]# kubectl  get secret csi-rbd-node-secret -o yaml
apiVersion: v1
data:
  userID: YWRtaW4=
  userKey: QVFCYlUvOW9LWWJCREJBQTZQOWlzRVhXUDdWL08yU0g3N0lwbVE9PQ==
kind: Secret
metadata:
  creationTimestamp: "2025-10-27T11:28:16Z"
  name: csi-rbd-node-secret
  namespace: default
  resourceVersion: "878758"
  uid: f4342627-ce95-42ca-a5c9-8d42ad96b9cf
type: Opaque
[root@10-211-55-32 ~]# 
```



- configmap  backup


```shell
[root@10-211-55-32 ~]# kubectl  get configmap ceph-config -o yaml
apiVersion: v1
data:
  ceph.conf: |
    [global]
    fsid = a9ae839a-b325-11f0-9192-001c4277e7e6
    mon_host = 10.211.55.34
    auth_cluster_required = cephx
    auth_service_required = cephx
    auth_client_required = cephx
  keyring: |
    [client.admin]
    key = AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"ceph.conf":"[global]\nfsid = a9ae839a-b325-11f0-9192-001c4277e7e6\nmon_host = 10.211.55.34\nauth_cluster_required = cephx\nauth_service_required = cephx\nauth_client_required = cephx\n","keyring":"[client.admin]\nkey = AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==\n"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"ceph-config","namespace":"default"}}
  creationTimestamp: "2025-10-27T09:04:41Z"
  name: ceph-config
  namespace: default
  resourceVersion: "850545"
  uid: 530afcd7-0108-4c9c-b4e8-e25de0416073
[root@10-211-55-32 ~]# 




[root@10-211-55-32 ~]# kubectl  get configmap ceph-config -o yaml
apiVersion: v1
data:
  ceph.conf: |
    [global]
    fsid = a9ae839a-b325-11f0-9192-001c4277e7e6
    mon_host = 10.211.55.34
    auth_cluster_required = cephx
    auth_service_required = cephx
    auth_client_required = cephx
  keyring: |
    [client.admin]
    key = AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"ceph.conf":"[global]\nfsid = a9ae839a-b325-11f0-9192-001c4277e7e6\nmon_host = 10.211.55.34\nauth_cluster_required = cephx\nauth_service_required = cephx\nauth_client_required = cephx\n","keyring":"[client.admin]\nkey = AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==\n"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"ceph-config","namespace":"default"}}
    meta.helm.sh/release-name: ceph-csi-rbd
    meta.helm.sh/release-namespace: default
  creationTimestamp: "2025-10-27T11:27:23Z"
  labels:
    app: ceph-csi-rbd
    app.kubernetes.io/managed-by: Helm
    chart: ceph-csi-rbd-3.12.0
    component: nodeplugin
    heritage: Helm
    release: ceph-csi-rbd
  name: ceph-config
  namespace: default
  resourceVersion: "878834"
  uid: 325709a4-8e8b-46ed-abff-695548e5d585
[root@10-211-55-32 ~]# kubectl  get configmap ceph-csi-config  -o yaml
apiVersion: v1
data:
  cluster-mapping.json: |-
    [
        {
          "clusterID": "a9ae839a-b325-11f0-9192-001c4277e7e6",
          "pool": "rbd"
        }
      ]
  config.json: |-
    [
        {
          "clusterID": "a9ae839a-b325-11f0-9192-001c4277e7e6",
          "monitors": [
            "10.211.55.34:6789"
          ]
        }
      ]
kind: ConfigMap
metadata:
  creationTimestamp: "2025-10-27T11:28:28Z"
  name: ceph-csi-config
  namespace: default
  resourceVersion: "878801"
  uid: f0e9c6c6-e611-4e37-a1a1-78afe64ef888
[root@10-211-55-32 ~]# 
```




- maybe useful cmd 

```shell

[root@10-211-55-32 ~]# kubectl  exec -it ceph-csi-rbd-provisioner-7695cf7998-gvb7n   -c csi-rbdplugin  -- rbd ls
testimage
[root@10-211-55-32 ~]# kubectl  exec -it ceph-csi-rbd-provisioner-7695cf7998-gvb7n   -c csi-rbdplugin  -- cat /etc/ceph/ceph.conf
[global]
fsid = a9ae839a-b325-11f0-9192-001c4277e7e6
mon_host = 10.211.55.34
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx

[client]
rbd cache = true
rbd cache writethrough until flush = true
[root@10-211-55-32 ~]# kubectl  exec -it ceph-csi-rbd-provisioner-7695cf7998-gvb7n   -c csi-rbdplugin  -- cat /etc/ceph/keyring
[client.admin]
key = AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==
caps mds = "allow *"
caps mgr = "allow *"
caps mon = "allow *"
caps osd = "allow *"
[root@10-211-55-32 ~]# 



[root@10-211-55-32 ~]# kubectl  exec -it ceph-csi-rbd-nodeplugin-4whbm    -c csi-rbdplugin  -- rbd ls
testimage
[root@10-211-55-32 ~]# kubectl  exec -it ceph-csi-rbd-nodeplugin-4whbm    -c csi-rbdplugin  -- cat /etc/ceph/ceph.conf
[global]
fsid = a9ae839a-b325-11f0-9192-001c4277e7e6
mon_host = 10.211.55.34
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx

[client]
rbd cache = true
rbd cache writethrough until flush = true
[root@10-211-55-32 ~]# kubectl  exec -it ceph-csi-rbd-nodeplugin-4whbm    -c csi-rbdplugin  -- cat /etc/ceph/keyring
[client.admin]
key = AQBbU/9oKYbBDBAA6P9isEXWP7V/O2SH77IpmQ==
caps mds = "allow *"
caps mgr = "allow *"
caps mon = "allow *"
caps osd = "allow *"
[root@10-211-55-32 ~]# 
```



## 10.Undo  


- clear your system


```shell get fsid 
[root@10-211-55-34 ~]# cephadm shell -- ceph fsid
Inferring fsid 497171ea-ae25-11f0-ba0d-001c4277e7e6
Inferring config /var/lib/ceph/497171ea-ae25-11f0-ba0d-001c4277e7e6/mon.10-211-55-34/config
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
497171ea-ae25-11f0-ba0d-001c4277e7e6
[root@10-211-55-34 ~]# 
```

```shell  rm cluster 
[root@10-211-55-34 ~]# cephadm rm-cluster --force --zap-osds --fsid  497171ea-ae25-11f0-ba0d-001c4277e7e6
Deleting cluster with fsid: 497171ea-ae25-11f0-ba0d-001c4277e7e6
Using ceph image with id '0f5473a1e726' and tag 'v18' created on 2025-05-08 01:48:39 +0800 CST
quay.io/ceph/ceph@sha256:1b9158ce28975f95def6a0ad459fa19f1336506074267a4b47c1bd914a00fec0
[root@10-211-55-34 ~]# 
[root@10-211-55-34 ~]# systemctl  restart docker
[root@10-211-55-34 ~]# 
[root@10-211-55-34 ~]# rm -rf /var/lib/ceph/
[root@10-211-55-34 ~]# rm -rf /var/log/ceph/
[root@10-211-55-34 ~]# rm -rf /etc/ceph/
[root@10-211-55-34 ~]# 
```

```shell remove 3 devices
[root@10-211-55-34 ~]# lvremove ceph-vg0/osd-lv0 -y
  Logical volume "osd-lv0" successfully removed.
[root@10-211-55-34 ~]# lvremove ceph-vg1/osd-lv1 -y
  Logical volume "osd-lv1" successfully removed.
[root@10-211-55-34 ~]# lvremove ceph-vg2/osd-lv2 -y
  Logical volume "osd-lv2" successfully removed.

[root@10-211-55-34 ~]# vgremove  ceph-vg0
  Volume group "ceph-vg0" successfully removed
[root@10-211-55-34 ~]# vgremove  ceph-vg1
  Volume group "ceph-vg1" successfully removed
[root@10-211-55-34 ~]# vgremove  ceph-vg2
  Volume group "ceph-vg2" successfully removed
[root@10-211-55-34 ~]# 

[root@10-211-55-34 ~]# pvremove  /dev/loop0 /dev/loop1 /dev/loop2
  Labels on physical volume "/dev/loop0" successfully wiped.
  Labels on physical volume "/dev/loop1" successfully wiped.
  Labels on physical volume "/dev/loop2" successfully wiped.
[root@10-211-55-34 ~]# 


[root@10-211-55-34 ~]# losetup -d /dev/loop0
[root@10-211-55-34 ~]# losetup -d /dev/loop1
[root@10-211-55-34 ~]# losetup -d /dev/loop2

[root@10-211-55-34 ~]# rm -rf /ceph-disks/osd0.img /ceph-disks/osd1.img /ceph-disks/osd2.img
[root@10-211-55-34 ~]# 



# remove some cmd for file /etc/rc.d/rc.local  

[root@10-211-55-34 ~]# cat  /etc/rc.d/rc.local 
#!/bin/bash
touch /var/lock/subsys/local

[root@10-211-55-34 ~]# 
```