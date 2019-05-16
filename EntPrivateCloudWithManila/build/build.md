
# Undercloud/OverCloud用ハードウェア設定
# Director用仮想サーバ作成



## OSP13

### 3.1.stack user 作成
OpenStackをインストールするため、sudoをパスワード無しで実行できるユーザを作成する。  
実行ホスト : director  
実行ユーザ : root

```
[root@director ~]# useradd stack
[root@director ~]# passwd stack
[root@director ~]# echo 'stack ALL=(root) NOPASSWD:ALL' | tee -a /etc/sudoers.d/stack
[root@undercloud ~]# chmod 0440 /etc/sudoers.d/stack
```

### 3.2.templateとmages用のディレクトリ作成
実行ホスト : director  
実行ユーザ : stack

```
[root@director ~]# su - stack
[stack@director ~]$　mkdir ~/templates
[stack@director ~]$　mkdir ~/images
```

### 3.3.hostname の確認

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
### 3.4.サブスクリプション登録と必要なレジストリーの有効化

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

### 3.5.director パッケージのインストール

director のインストールと設定を行うためのコマンドラインツールと
Ceph Storageノードを使うためのツールのインストール

```
[stack@director ~]$ sudo yum install -y python-tripleoclient
[stack@director ~]$ sudo yum install -y ceph-ansible
```

### 3.6.directorのインストール

githubにある「undercloud.conf」を
/home/stackに配置した後、以下のコマンドを実行する。

```
[stack@director ~]$ openstack undercloud install
```

undercloud.conf の設定に合わせてサービスが設定される。
このスクリプトは、完了までに数分かかる。
WARNINGメッセージが出るが無視してOK

正常にインストールされると以下のふたつのファイルが生成される

- undercloud-passwords.conf : director サービスの全パスワード一覧  
- stackrc : director のコマンドラインツールへアクセスできるようにする初期化変数セット


### 3.7.オーバークラウドノードのイメージの取得

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

インポートの確認（出力例）
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

### 3.8.コンテナーイメージのソースの設定
イメージをローカルレジストリーを設定し、オーバークラウドのコンテナーイメージを保管する

```
(undercloud) [stack@director ~]$ openstack overcloud container image prepare \
--namespace=registry.access.redhat.com/rhosp13 \
--push-destination=192.168.110.10:8787 \
--prefix=openstack- \
--tag-from-label {version}-{release}  \
--output-env-file=/home/stack/templates/overcloud_images.yaml   \
--output-images-file /home/stack/local_registry_images.yaml


(undercloud) [stack@director ~]$ sudo openstack overcloud container image upload \
--config-file /home/stack/local_registry_images.yaml --verbose

```

### 3.9.オーバークラウドへのノード登録

JSON形式のファイルにハードウェアの電源管理の情報を記述する。
雛形としてgithubにある「instack.adp.json」を利用する。
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
            "pm_addr":"192.168.100.11",
            "capabilities": "profile:control,boot_option:local,node:controller-0",
            "arch":"x86_64"
        },
        {
            "name": "ctrl002",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.12",
            "capabilities": "profile:control,boot_option:local,node:controller-1",
            "arch":"x86_64"
        },
        {
            "name": "ctrl003",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.13",
            "capabilities": "profile:control,boot_option:local,node:controller-2",
            "arch":"x86_64"
        },
        {
            "name": "kvm001",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.21",
            "capabilities": "profile:compute,boot_option:local,node:compute-0",
            "arch":"x86_64"
        },
        {
            "name": "kvm002",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.22",
            "capabilities": "profile:compute,boot_option:local,node:compute-1",
            "arch":"x86_64"
        },
        {
            "name": "kvm003",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.23",
            "capabilities": "profile:compute,boot_option:local,node:compute-2",
            "arch":"x86_64"
        },
        {
            "name": "ceph001",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.61",
            "capabilities": "profile:ceph-storage,boot_option:local,node:cephstorage-0",
            "arch":"x86_64"
        },
        {
            "name": "ceph002",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.62",
            "capabilities": "profile:ceph-storage,boot_option:local,node:cephstorage-1",
            "arch":"x86_64"
        },
        {
            "name": "ceph003",
            "pm_type":"pxe_ipmitool",
            "pm_user":"root",
            "pm_password":"root",
            "pm_addr":"192.168.100.63",
            "capabilities": "profile:ceph-storage,boot_option:local,node:cephstorage-2",
            "arch":"x86_64"
        }
    ]
}
```


設定情報をインポートする

```
(undercloud) [stack@director ~]$ openstack overcloud node import ./instack.adp.json
(undercloud) [stack@director ~]$ openstack overcloud node introspect --all-manageable --provide
```


登録の確認
```
(undercloud) [stack@director ~]$ openstack baremetal node list
+--------------------------------------+---------+--------------------------------------+-------------+--------------------+-------------+
| UUID                                 | Name    | Instance UUID                        | Power State | Provisioning State | Maintenance |
+--------------------------------------+---------+--------------------------------------+-------------+--------------------+-------------+
| 277bf0bd-f747-4aed-a176-c857a2fe6f27 | ctrl001 | 65f38a9b-a54b-4535-8863-8d7fca0a3431 | power on    | active             | False       |
| abb31963-fd2f-4684-bdc5-102e1b48772a | ctrl002 | cea19755-786b-4218-b705-cb30e1c63dd5 | power on    | active             | False       |
| ef61eac3-f7c9-47cf-a094-d48fadefc32c | ctrl003 | 1faea303-a62a-40bf-95ec-1f735a20197a | power on    | active             | False       |
| 84df391b-bc59-4b4e-bda3-746fd30ed9ca | kvm001  | 828a4927-15a1-4a53-aefd-b113e74895f0 | power on    | active             | False       |
| 905758c4-3fab-4ca7-a1d5-2a496397fb79 | kvm002  | 1231f55b-645c-4360-b2a0-b83c77ed0410 | power on    | active             | False       |
| b3b5d7b2-a716-4e0a-be92-8e86874cc973 | kvm003  | 6bb98c39-e196-4e05-a313-72d57958c38a | power on    | active             | False       |
| 6d100d8c-61e4-4aad-8846-04834ae5140c | ceph001 | 245a861f-9e10-45b8-a32f-c01142641de2 | power on    | active             | False       |
| 477876b5-c2a1-4e61-b22a-acc69fb621bb | ceph002 | 6da6788b-5263-4635-b821-4a515d07583a | power on    | active             | False       |
| f2799258-6a46-4c88-b3ae-993a5f792f04 | ceph003 | 8df5d224-71ef-45cf-ad47-e250064616f8 | power on    | active             | False       |
+--------------------------------------+---------+--------------------------------------+-------------+--------------------+-------------+
```


### 3.10.オーバークラウドへの設定ファイルの準備
下記のファイルを本githubリポジトリ内の ["openstack-director"](./openstack-director) から入手し、directorの指定のディレクトリに配置

```
/home/stack/templates


/home/stack/templates/nic-configs


/home/stack/templates/ports
```


### 3.11.オーバークラウドデプロイ
/home/stack/deploy.shを実行

読み込む設定ファイルの数によって、数十分かかる場合もある。

deploy.shの内容

```
#!/usr/bin/env bash
if [ $PWD != $HOME ] ; then echo "USAGE: $0 Must be run from $HOME"; exit 1 ; fi

stack_name=adpcloud

time openstack overcloud deploy --verbose \
 --templates /usr/share/openstack-tripleo-heat-templates \
 -e /home/stack/templates/global-config.yaml \
 -e /home/stack/templates/cloud-names.yaml \
 -e /home/stack/templates/enable-tls.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/tls-endpoints-public-ip.yaml \
 -e /home/stack/templates/inject-trust-anchor.yaml \
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
 --timeout 210 \
 --ntp-server ntp.nict.jp \
 --log-file ./overcloud_deploy.log \
 --stack $stack_name

```

### 3.12.オーバークラウドデプロイの確認
環境ファイル ```/home/stack/templates/network-environment.yaml``` で設定したパブリックIPアドレスにブラウザでアクセスする。  
Red Hat OpenStack Platform Dashboardのログイン画面が表示されることを確認する。

```
[stack@director ~]$ grep PublicVirtualFixedIPs /home/stack/templates/network-environment.yaml
#        "PublicVirtualFixedIPs": [
  PublicVirtualFixedIPs: [{'ip_address':'10.208.81.244'}]

ブラウザで https://10.208.81.244/
```
デフォルトの管理者ユーザー名は "admin"  
admin のパスワードは、オーバークラウドデプロイに成功した際に、/home/stackに作られる変数セットのファイル ""<i>stack_name</i>rc" の中に書かれている。
```
[stack@director ~]$ ls *rc
adpcloudrc  stackrc
[stack@director ~]$ grep PASSWORD adpcloudrc
export OS_PASSWORD=kaTvFrTDgJ2Df9mKNFtFfzHAb
```
