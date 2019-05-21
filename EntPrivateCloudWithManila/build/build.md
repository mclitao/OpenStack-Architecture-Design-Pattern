# OpenStack Platform の構築

## 1. undercloud ( director ) の構築

### 1.1 director ホストのOSインストール＆セットアップ

RHEL をインストールし、Network の設定を行う。

* IPアドレス設定が必要なネットワーク
  * External ( 10.0.0.0/16)
  * Management ( 192.168.120.0/24 )
  * IPMI ( 192.168.100.0/24 )

### 1.2 stack user 作成
OpenStackをインストールするため、sudoをパスワード無しで実行できるユーザを作成する。  
実行ホスト : director  
実行ユーザ : root

```
[root@director ~]# useradd stack
[root@director ~]# passwd stack
[root@director ~]# echo 'stack ALL=(root) NOPASSWD:ALL' | tee -a /etc/sudoers.d/stack
[root@undercloud ~]# chmod 0440 /etc/sudoers.d/stack
```

### 1.3 templateとmages用のディレクトリ作成
実行ホスト : director  
実行ユーザ : stack

```
[root@director ~]# su - stack
[stack@director ~]$　mkdir ~/templates
[stack@director ~]$　mkdir ~/images
```

### 1.4 hostname の確認

```
[stack@director ~]$ hostname
director.adp.local

[stack@director ~]$ hostname -f
director.adp.local

※ 同じ値が帰ってくることを確認する。
※ 異なる場合は修正する

[stack@director ~]$ sudo hostnamectl set-hostname director.adp.local
[stack@director ~]$ sudo hostnamectl set-hostname --transient director.adp.local
```
### 1.5 サブスクリプション登録と必要なリポジトリの有効化

```
[stack@director ~]$ sudo subscription-manager register
[stack@director ~]$ sudo subscription-manager list --available --all --matches="Red Hat OpenStack”

出力結果の「Pool ID」を確認する
Pool ID:             XXXXXXXXXXXXXXXXXX

確認たPool IDをattachする。

[stack@director ~]$ subscription-manager attach --pool=XXXXXXXXXXXXXXXXXX

[stack@director ~]$ sudo subscription-manager repos --disable=* --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-rh-common-rpms --enable=rhel-ha-for-rhel-7-server-rpms --enable=rhel-7-server-openstack-13-rpms
[stack@director ~]$ sudo yum update -y
[stack@director ~]$ sudo reboot
```

### 1.6 director パッケージのインストール

director のインストールと設定を行うためのコマンドラインツールと
Ceph Storageノードを使うためのツールのインストール

```
[stack@director ~]$ sudo yum install -y python-tripleoclient
[stack@director ~]$ sudo yum install -y ceph-ansible
```

### 1.7 directorのインストール

githubにある[undercloud.conf](https://github.com/toaraki/OpenStack-Architecture-Design-Pattern-1/blob/master/EntPrivateCloudWithManila/openstack-director/undercloud.conf)を/home/stackに配置した後、以下のコマンドを実行する。

```
[stack@director ~]$ openstack undercloud install
```

undercloud.conf の設定に合わせてサービスが設定される。
このスクリプトは、完了までに数分かかる。
WARNINGメッセージが出るが無視してOK

正常にインストールされると以下のふたつのファイルが生成される

- undercloud-passwords.conf : director サービスの全パスワード一覧  
- stackrc : director のコマンドラインツールへアクセスできるようにする初期化変数セット

### 1.8 オーバークラウドノードのイメージの取得

#### イメージインポートの実施
stackrc ファイルを読み込んで、director のコマンドラインツールを有効にして
オーバークラウドのイメージをホームディレクトリの~imagesに展開し
directorにインポートする

```
[stack@director ~]$ source ~/stackrc

(undercloud) [stack@director ~]$ sudo yum install rhosp-director-images rhosp-director-images-ipa
(undercloud) [stack@director ~]$ cd ~/images
(undercloud) [stack@director images]$ for i in /usr/share/rhosp-director-images/overcloud-full-latest-13.0.tar /usr/share/rhosp-director-images/ironic-python-agent-latest-13.0.tar; do tar -xvf $i; done
(undercloud) [stack@director images]$ openstack overcloud image upload --image-path /home/stack/images/
```

#### インポートの確認（出力例）
```
(undercloud) [stack@director ~]$ openstack image list
+--------------------------------------+------------------------+--------+
| ID                                   | Name                   | Status |
+--------------------------------------+------------------------+--------+
| 02acdc2d-c7d0-4800-a911-180d956b1d15 | bm-deploy-kernel       | active |
| e8336509-9e3e-4274-91cc-a6fcccf7055f | bm-deploy-ramdisk      | active |
| 9295502c-37ad-4126-8d38-48c660f82f16 | overcloud-full         | active |
| 8de2af0e-fe00-40d0-afdc-5083b5a616f9 | overcloud-full-initrd  | active |
| 8a364a9a-8afd-43b9-8052-86ec0792bf8e | overcloud-full-vmlinuz | active |
+--------------------------------------+------------------------+--------+

```

## 2 オーバークラウドの構築

### 2.1 オーバークラウドへのノード登録

#### bearemetal 登録用 JSONファイルの作成

JSON形式のファイルにハードウェアの電源管理の情報を記述する。
雛形としてgithubにある「[instack.adp.json](https://github.com/toaraki/OpenStack-Architecture-Design-Pattern-1/blob/master/EntPrivateCloudWithManila/openstack-director/instack.adp.json)」を利用する。
ハードウェアの設定に依存する部分は環境に合わせる。

※pm_userおよびpm_passwordはハードウェアの設定に依存する

```
{
    "nodes":[
        {
            "name": "ctrl001",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.24",
            "capabilities": "profile:control,boot_option:local,node:controller-0",
            "arch":"x86_64"
        },
        {
            "name": "ctrl002",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.25",
            "capabilities": "profile:control,boot_option:local,node:controller-1",
            "arch":"x86_64"
        },
        {
            "name": "ctrl003",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.26",
            "capabilities": "profile:control,boot_option:local,node:controller-2",
            "arch":"x86_64"
        },
        {
            "name": "kvm001",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.32",
            "capabilities": "profile:compute,boot_option:local,node:compute-0",
            "arch":"x86_64"
        },
        {
            "name": "kvm002",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.33",
            "capabilities": "profile:compute,boot_option:local,node:compute-1",
            "arch":"x86_64"
        },
        {
            "name": "kvm003",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.34",
            "capabilities": "profile:compute,boot_option:local,node:compute-2",
            "arch":"x86_64"
        },
        {
            "name": "ceph001",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.232",
            "capabilities": "profile:ceph-storage,boot_option:local,node:cephstorage-0",
            "arch":"x86_64"
        },
        {
            "name": "ceph002",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.233",
            "capabilities": "profile:ceph-storage,boot_option:local,node:cephstorage-1",
            "arch":"x86_64"
        },
        {
            "name": "ceph003",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.234",
            "capabilities": "profile:ceph-storage,boot_option:local,node:cephstorage-2",
            "arch":"x86_64"
        }
    ]
}
```


#### 設定情報をインポートする

```
(undercloud) [stack@director ~]$ openstack overcloud node import ./instack.adp.json
(undercloud) [stack@director ~]$ openstack overcloud node introspect --all-manageable --provide
```


#### 登録の確認
```
(undercloud) [stack@director ~]$ openstack baremetal node list
+--------------------------------------+---------+---------------+-------------+--------------------+-------------+                                                                                               
| UUID                                 | Name    | Instance UUID | Power State | Provisioning State | Maintenance |                                                                                               
+--------------------------------------+---------+---------------+-------------+--------------------+-------------+                                                                                               
| 440a258b-445d-4b4c-878f-48c45ced87d7 | ctrl001 | None          | power off   | available          | False       |                                                                                               
| 9b6afe2f-938e-4e0a-b45b-d6e78f580651 | ctrl002 | None          | power off   | available          | False       |                                                                                               
| e69e3c20-bea8-479a-94f4-32208dd67a10 | ctrl003 | None          | power off   | available          | False       |                                                                                               
| cfcfb9a5-b930-4614-befa-a7fba4f7178a | kvm001  | None          | power off   | available          | False       |                                                                                               
| b68441e0-9eb7-43e9-8d1c-32cb4897ef47 | kvm002  | None          | power off   | available          | False       |                                                                                               
| 96a8cf7f-879b-495f-99d3-fa7d76f94397 | kvm003  | None          | power off   | available          | False       |                                                                                               
| b1921cd7-6298-4fcf-8b4d-0367308f7a5e | ceph001 | None          | power off   | available          | False       |                                                                                               
| 4d2a3a71-fff8-4490-8700-56d547730b41 | ceph002 | None          | power off   | available          | False       |                                                                                               
| c9c2d590-b706-4542-abe7-e57d59b8dfcc | ceph003 | None          | power off   | available          | False       |                                                                                               
+--------------------------------------+---------+---------------+-------------+--------------------+-------------+ 
(undercloud) [stack@director ~]$ 

```


### 2.2 オーバークラウドへの設定ファイルの準備
下記のファイルを本githubリポジトリ内の ["openstack-director"](https://github.com/toaraki/OpenStack-Architecture-Design-Pattern-1/tree/master/EntPrivateCloudWithManila/openstack-director) から入手し、directorの指定のディレクトリに配置

```
/home/stack/templates


/home/stack/templates/nic-configs


/home/stack/templates/ports
```

### 2.3 コンテナーイメージのソースの設定
イメージをローカルレジストリーを設定し、オーバークラウドのコンテナーイメージを保管する.
* ["openstack-director/container-image-prepare.sh"](https://github.com/toaraki/OpenStack-Architecture-Design-Pattern-1/blob/master/EntPrivateCloudWithManila/openstack-director/container-image-prepare.sh)

```
(undercloud) [stack@director ~]$ openstack overcloud container image prepare \
 --namespace=registry.access.redhat.com/rhosp13 \
 --push-destination=192.168.110.1:8787 \
 --prefix=openstack- \
 --tag-from-label {version}-{release}  \
 --output-env-file=/home/stack/templates/overcloud_images.yaml \
 --output-images-file /home/stack/local_registry_images.yaml \
 -e /home/stack/templates/roles_data.yaml \
 -e /home/stack/templates/global-config.yaml \
 -e /home/stack/templates/cloud-names.yaml \
 -e /home/stack/templates/scheduler_hints_env.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/docker.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/docker-ha.yaml  \
 -e /home/stack/templates/overcloud_images.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/net-bond-with-vlans.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/network-management.yaml  \
 -e /home/stack/templates/network-environment.yaml \
 -e /home/stack/templates/ips-from-pool-all.yaml \
 -e /home/stack/templates/ceph-storage-environment.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/manila-cephfsganesha-config.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/cinder-backup.yaml

...

(undercloud) [stack@director ~]$ sudo openstack overcloud container image upload \
--config-file /home/stack/local_registry_images.yaml --verbose

```

### 2.4 オーバークラウドデプロイ
[/home/stack/deploy.sh](https://github.com/toaraki/OpenStack-Architecture-Design-Pattern-1/blob/master/EntPrivateCloudWithManila/openstack-director/deploy.sh)を実行する。

読み込む設定ファイルの数や、マシンスペックによって、60〜90分程度かかる場合がある。

deploy.shの内容

```
#!/usr/bin/env bash
if [ $PWD != $HOME ] ; then echo "USAGE: $0 Must be run from $HOME"; exit 1 ; fi

stack_name=adpcloud

source ~/stackrc

time openstack overcloud deploy --verbose \
 --templates /usr/share/openstack-tripleo-heat-templates \
 -n /usr/share/openstack-tripleo-heat-templates/network_data_ganesha.yaml \
 -e /home/stack/templates/roles_data.yaml \
 -e /home/stack/templates/global-config.yaml \
 -e /home/stack/templates/cloud-names.yaml \
 -e /home/stack/templates/scheduler_hints_env.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/docker.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/docker-ha.yaml  \
 -e /home/stack/templates/overcloud_images.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/net-bond-with-vlans.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/network-management.yaml  \
 -e /home/stack/templates/network-environment.yaml \
 -e /home/stack/templates/ips-from-pool-all.yaml \
 -e /home/stack/templates/ceph-storage-environment.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/manila-cephfsganesha-config.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/cinder-backup.yaml \
 --timeout 210 \
 --ntp-server ntp.nict.jp \
 --log-file ./overcloud_deploy.log \
 --stack $stack_name

```

### 2.5 オーバークラウドデプロイの確認

環境ファイル ```/home/stack/templates/network-environment.yaml``` で設定したパブリックIPアドレスにブラウザでアクセスする。  

Webブラウザで、Red Hat OpenStack Platform Dashboardのログイン画面が表示されることを確認する。

```
[stack@director ~]$ grep PublicVirtualFixedIPs /home/stack/templates/network-environment.yaml

  PublicVirtualFixedIPs: [{'ip_address':'10.0.255.248'}]

```

* ブラウザで https://10.208.81.244/ へアクセスする。

デフォルトの管理者ユーザー名は "admin"  

* adminパスワードの確認
admin のパスワードは、オーバークラウドデプロイに成功した際に、/home/stackに作られる変数セットのファイル ""<i>stack_name</i>rc" の中に書かれている。
```
[stack@director ~]$ ls *rc
adpcloudrc  stackrc
[stack@director ~]$ grep PASSWORD adpcloudrc
export OS_PASSWORD=kaTvFrTDgJ2Df9mKNFtFfzHAb
```
