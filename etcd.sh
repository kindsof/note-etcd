################问题处理
ntpdate ntp1.aliyun.com





超时：

Jul 10 17:21:48 k2 etcd: server is likely overloaded
Jul 10 17:21:48 k2 etcd: failed to send out heartbeat on time (exceeded the 100ms timeout for 13.482876ms)
Jul 10 17:21:48 k2 etcd: server is likely overloaded
超时，需要修改
[root@k4 kubelet.service.d]# vim /etc/etcd/etcd.conf

ETCD_HEARTBEAT_INTERVAL="1000"
ETCD_ELECTION_TIMEOUT="6000" #这里必须大于1000的5倍，否则启动不起来etcd
（（

[root@k2 kubernetes]# systemctl restart etcd
Job for etcd.service failed because the control process exited with error code. See "systemctl status etcd.service" and "journalctl -xe" for details.


））
重新启动etcd


无法连接， 删除已经存在的目录，重新启动的时候最好指定目录

setting maximum number of CPUs to 2, total number of available CPUs is 2
Jul 10 17:55:10 k4 etcd[7299]: error listing data dir: /var/lib/etcd/default.etcd
Jul 10 17:55:10 k4 systemd[1]: etcd.service: main process exited, code=exited, status=1/FAILURE
Jul 10 17:55:10 k4 systemd[1]: Failed to start Etcd Server.

##################

注意：所有ETCD_MY_FLAG的配置参数也可以通过命令行参数进行设置，但是命令行指定的参数优先级更高，同时存在时会覆盖环境变量对应的值。


启动完成后，在任意节点执行etcdctl member list可列所有集群节点信息，如下所示：


$ etcdctl --endpoints "http://192.168.2.210:2379" member list
a3ba19408fd4c829: name=etcd3 peerURLs=http://192.168.2.212:2380 clientURLs=http://192.168.2.212:2379,http://192.168.2.212:4001 isLeader=true
a8589aa8629b731b: name=etcd1 peerURLs=http://192.168.2.210:2380 clientURLs=http://192.168.2.210:2379,http://192.168.2.210:4001 isLeader=false
e4a3e95f72ced4a7: name=etcd2 peerURLs=http://192.168.2.211:2380 clientURLs=http://192.168.2.211:2379,http://192.168.2.211:4001 isLeader=false

这里显示指定的集群地址，是因为在上面的配置中绑定了IP。如不指定会报如下错误：

$ etcdctl member list
Error:  client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:4001: getsockopt: connection refused
; error #1: dial tcp 127.0.0.1:2379: getsockopt: connection refused

error #0: dial tcp 127.0.0.1:4001: getsockopt: connection refused
error #1: dial tcp 127.0.0.1:2379: getsockopt: connection refused

######################
这篇文章很好。
https://www.hi-linux.com/posts/49138.html 

在「etcd使用入门」一文中对etcd的基本知识点和安装做了一个简要的介绍，这次我们来说说如何部署一个etcd集群。

etcd构建自身高可用集群主要有三种形式:

    静态发现: 预先已知etcd集群中有哪些节点，在启动时通过--initial-cluster参数直接指定好etcd的各个节点地址。

    etcd动态发现: 通过已有的etcd集群作为数据交互点，然后在扩展新的集群时实现通过已有集群进行服务发现的机制。比如官方提供的：discovery.etcd.io

    DNS动态发现: 通过DNS查询方式获取其他节点地址信息。

本文将介绍如何通过静态发现这种方式来部署一个etcd集群，这种方式也是最简单的。

环境准备

通常按照需求将集群节点部署为3，5，7，9个节点。这里能选择偶数个节点吗？最好不要这样。原因有二：

    偶数个节点集群不可用风险更高，表现在选主过程中，有较大概率或等额选票，从而触发下一轮选举。
    偶数个节点集群在某些网络分割的场景下无法正常工作。当网络分割发生后，将集群节点对半分割开。此时集群将无法工作。按照RAFT协议，此时集群写操作无法使得大多数节点同意，从而导致写失败，集群无法正常工作。

这里将部署一个3节点的集群， 以下为3台主机信息，系统环境为Ubuntu 16.04。
节点名称  地址
etcd1   192.168.2.210
etcd2   192.168.2.211
etcd3   192.168.2.212

安装etcd

在「etcd使用入门」一文中对如何安装已经做了介绍，这里就不再重复讲解了。如果你还不会安装可参考「etcd使用入门」。

配置etcd集群

修改etcd配置文件,我这里的环境是在/opt/etcd/config/etcd.conf，请根据实际情况修改。

    etcd1配置示例

 

# 编辑配置文件
$ vim /opt/etcd/config/etcd.conf

ETCD_NAME=etcd1
ETCD_DATA_DIR="/var/lib/etcd/etcd1"
ETCD_LISTEN_PEER_URLS="http://192.168.2.210:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.2.210:2379,http://192.168.2.210:4001"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.2.210:2380"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.2.210:2380,etcd2=http://192.168.2.211:2380,etcd3=http://192.168.2.212:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="hilinux-etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.2.210:2379,http://192.168.2.210:4001"

    etcd2配置示例

 

# 编辑配置文件
$ vim /opt/etcd/config/etcd.conf

ETCD_NAME=etcd2
ETCD_DATA_DIR="/var/lib/etcd/etcd2"
ETCD_LISTEN_PEER_URLS="http://192.168.2.211:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.2.211:2379,http://192.168.2.211:4001"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.2.211:2380"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.2.210:2380,etcd2=http://192.168.2.211:2380,etcd3=http://192.168.2.212:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="hilinux-etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.2.211:2379,http://192.168.2.211:4001"

    etcd3配置示例

 

# 编辑配置文件
$ vim /opt/etcd/config/etcd.conf

ETCD_NAME=etcd3
ETCD_DATA_DIR="/var/lib/etcd/etcd3"
ETCD_LISTEN_PEER_URLS="http://192.168.2.212:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.2.212:2379,http://192.168.2.212:4001"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.2.212:2380"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.2.210:2380,etcd2=http://192.168.2.211:2380,etcd3=http://192.168.2.212:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="hilinux-etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.2.212:2379,http://192.168.2.212:4001"

针对上面几个配置参数做下简单的解释：

    ETCD_NAME ：ETCD的节点名
    ETCD_DATA_DIR：ETCD的数据存储目录
    ETCD_SNAPSHOT_COUNTER：多少次的事务提交将触发一次快照
    ETCD_HEARTBEAT_INTERVAL：ETCD节点之间心跳传输的间隔，单位毫秒
    ETCD_ELECTION_TIMEOUT：该节点参与选举的最大超时时间，单位毫秒
    ETCD_LISTEN_PEER_URLS：该节点与其他节点通信时所监听的地址列表，多个地址使用逗号隔开，其格式可以划分为scheme://IP:PORT，这里的scheme可以是http、https
    ETCD_LISTEN_CLIENT_URLS：该节点与客户端通信时监听的地址列表
    ETCD_INITIAL_ADVERTISE_PEER_URLS：该成员节点在整个集群中的通信地址列表，这个地址用来传输集群数据的地址。因此这个地址必须是可以连接集群中所有的成员的。
    ETCD_INITIAL_CLUSTER：配置集群内部所有成员地址，其格式为：ETCD_NAME=ETCD_INITIAL_ADVERTISE_PEER_URLS，如果有多个使用逗号隔开
    ETCD_ADVERTISE_CLIENT_URLS：广播给集群中其他成员自己的客户端地址列表
    ETCD_INITIAL_CLUSTER_STATE：初始化集群状态，new表示新建
    ETCD_INITIAL_CLUSTER_TOKEN:初始化集群token

    注意：所有ETCD_MY_FLAG的配置参数也可以通过命令行参数进行设置，但是命令行指定的参数优先级更高，同时存在时会覆盖环境变量对应的值。

下面给出常用配置的参数和它们的解释：


--name：方便理解的节点名称，默认为default，在集群中应该保持唯一，可以使用 hostname
--data-dir：服务运行数据保存的路径，默认为 ${name}.etcd
--snapshot-count：指定有多少事务（transaction）被提交时，触发截取快照保存到磁盘
--heartbeat-interval：leader 多久发送一次心跳到 followers。默认值是 100ms
--eletion-timeout：重新投票的超时时间，如果 follow 在该时间间隔没有收到心跳包，会触发重新投票，默认为 1000 ms
--listen-peer-urls：和同伴通信的地址，比如 http://ip:2380，如果有多个，使用逗号分隔。需要所有节点都能够访问，所以不要使用 localhost！
--listen-client-urls：对外提供服务的地址：比如 http://ip:2379,http://127.0.0.1:2379，客户端会连接到这里和 etcd 交互
--advertise-client-urls：对外公告的该节点客户端监听地址，这个值会告诉集群中其他节点
--initial-advertise-peer-urls：该节点同伴监听地址，这个值会告诉集群中其他节点
--initial-cluster：集群中所有节点的信息，格式为 node1=http://ip1:2380,node2=http://ip2:2380,…。注意：这里的 node1 是节点的 --name 指定的名字；后面的 ip1:2380 是 --initial-advertise-peer-urls 指定的值
--initial-cluster-state：新建集群的时候，这个值为new；假如已经存在的集群，这个值为 existing
--initial-cluster-token：创建集群的token，这个值每个集群保持唯一。这样的话，如果你要重新创建集群，即使配置和之前一样，也会再次生成新的集群和节点 uuid；否则会导致多个集群之间的冲突，造成未知的错误

所有以--init开头的配置都是在bootstrap集群的时候才会用到，后续节点的重启会被忽略。

测试etcd集群

按上面配置好各集群节点后，分别在各节点启动etcd。


$ systemctl start etcd

启动完成后，在任意节点执行etcdctl member list可列所有集群节点信息，如下所示：



$ etcdctl --endpoints "http://192.168.2.210:2379" member list
a3ba19408fd4c829: name=etcd3 peerURLs=http://192.168.2.212:2380 clientURLs=http://192.168.2.212:2379,http://192.168.2.212:4001 isLeader=true
a8589aa8629b731b: name=etcd1 peerURLs=http://192.168.2.210:2380 clientURLs=http://192.168.2.210:2379,http://192.168.2.210:4001 isLeader=false
e4a3e95f72ced4a7: name=etcd2 peerURLs=http://192.168.2.211:2380 clientURLs=http://192.168.2.211:2379,http://192.168.2.211:4001 isLeader=false

这里显示指定的集群地址，是因为在上面的配置中绑定了IP。如不指定会报如下错误：



$ etcdctl member list
Error:  client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:4001: getsockopt: connection refused
; error #1: dial tcp 127.0.0.1:2379: getsockopt: connection refused

error #0: dial tcp 127.0.0.1:4001: getsockopt: connection refused
error #1: dial tcp 127.0.0.1:2379: getsockopt: connection refused

etcd集群基本管理

    查看集群健康状态


$ etcdctl --endpoints "http://192.168.2.210:2379"  cluster-health
member a3ba19408fd4c829 is healthy: got healthy result from http://192.168.2.212:2379
member a8589aa8629b731b is healthy: got healthy result from http://192.168.2.210:2379
member e4a3e95f72ced4a7 is healthy: got healthy result from http://192.168.2.211:2379
cluster is healthy

    查看集群成员

在任一节点上执行，可以看到集群的节点情况，并能看出哪个是leader节点。


$ etcdctl --endpoints "http://192.168.2.210:2379" member list
a3ba19408fd4c829: name=etcd3 peerURLs=http://192.168.2.212:2380 clientURLs=http://192.168.2.212:2379,http://192.168.2.212:4001 isLeader=true
a8589aa8629b731b: name=etcd1 peerURLs=http://192.168.2.210:2380 clientURLs=http://192.168.2.210:2379,http://192.168.2.210:4001 isLeader=false
e4a3e95f72ced4a7: name=etcd2 peerURLs=http://192.168.2.211:2380 clientURLs=http://192.168.2.211:2379,http://192.168.2.211:4001 isLeader=false

    更新一个节点

 

# 如果你想更新一个节点的IP(peerURLS)，首先你需要知道那个节点的ID
$ etcdctl --endpoints "http://192.168.2.210:2379" member list
a3ba19408fd4c829: name=etcd3 peerURLs=http://192.168.2.212:2380 clientURLs=http://192.168.2.212:2379,http://192.168.2.212:4001 isLeader=false
a8589aa8629b731b: name=etcd1 peerURLs=http://192.168.2.210:2380 clientURLs=http://192.168.2.210:2379,http://192.168.2.210:4001 isLeader=false
e4a3e95f72ced4a7: name=etcd2 peerURLs=http://192.168.2.211:2380 clientURLs=http://192.168.2.211:2379,http://192.168.2.211:4001 isLeader=true

# 更新一个节点
$ etcdctl --endpoints "http://192.168.2.210:2379" member update a8589aa8629b731b http://192.168.2.210:2380
Updated member with ID a8589aa8629b731b in cluster

    删除一个节点
 

$ etcdctl --endpoints "http://192.168.2.210:2379" member list
a3ba19408fd4c829: name=etcd3 peerURLs=http://192.168.2.212:2380 clientURLs=http://192.168.2.212:2379,http://192.168.2.212:4001 isLeader=false
a8589aa8629b731b: name=etcd1 peerURLs=http://192.168.2.210:2380 clientURLs=http://192.168.2.210:2379,http://192.168.2.210:4001 isLeader=false
e4a3e95f72ced4a7: name=etcd2 peerURLs=http://192.168.2.211:2380 clientURLs=http://192.168.2.211:2379,http://192.168.2.211:4001 isLeader=true

$ etcdctl --endpoints "http://192.168.2.210:2379" member remove a8589aa8629b731b
Removed member a8589aa8629b731b from cluster

$ etcdctl --endpoints "http://192.168.2.211:2379" member list
a3ba19408fd4c829: name=etcd3 peerURLs=http://192.168.2.212:2380 clientURLs=http://192.168.2.212:2379,http://192.168.2.212:4001 isLeader=false
e4a3e95f72ced4a7: name=etcd2 peerURLs=http://192.168.2.211:2380 clientURLs=http://192.168.2.211:2379,http://192.168.2.211:4001 isLeader=true

    增加一个新节点

    注意:步骤很重要，不然会报集群ID不匹配。

a. 将目标节点添加到集群
  

$ etcdctl --endpoints "http://192.168.2.211:2379" member add etcd1 http://192.168.2.210:2380

Added member named etcd1 with ID baab0aae8b58c802 to cluster

ETCD_NAME="etcd1"
ETCD_INITIAL_CLUSTER="etcd3=http://192.168.2.212:2380,etcd1=http://192.168.2.210:2380,etcd2=http://192.168.2.211:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"

b. 查看新增成员列表

etcd1状态现在为unstarted



$ etcdctl --endpoints "http://192.168.2.211:2379" member list
a3ba19408fd4c829: name=etcd3 peerURLs=http://192.168.2.212:2380 clientURLs=http://192.168.2.212:2379,http://192.168.2.212:4001 isLeader=false
baab0aae8b58c802[unstarted]: peerURLs=http://192.168.2.210:2380
e4a3e95f72ced4a7: name=etcd2 peerURLs=http://192.168.2.211:2380 clientURLs=http://192.168.2.211:2379,http://192.168.2.211:4001 isLeader=true

c. 清空目标节点数据

目标节点从集群中删除后，成员信息会更新。新节点是作为一个全新的节点加入集群，如果data-dir有数据，etcd启动时会读取己经存在的数据，仍然用旧的memberID会造成无法加入集群，所以一定要清空新节点的data-dir。

1

  

$ rm -rf /var/lib/etcd/etcd1

d. 在目标节点上启动新增加的成员

修改配置文件中ETCD_INITIAL_CLUSTER_STATE标记为existing，如果为new，则会自动生成一个新的memberID，这和前面添加节点时生成的ID不一致，故日志中会报节点ID不匹配的错。

  

$ vim /opt/etcd/config/etcd.conf
ETCD_INITIAL_CLUSTER_STATE="existing"

启动etcd


$ systemctl start etcd

查看新节点是否成功加入



$ etcdctl --endpoints "http://192.168.2.210:2379" member list
a3ba19408fd4c829: name=etcd3 peerURLs=http://192.168.2.212:2380 clientURLs=http://192.168.2.212:2379,http://192.168.2.212:4001 isLeader=false
baab0aae8b58c802: name=etcd1 peerURLs=http://192.168.2.210:2380 clientURLs=http://192.168.2.210:2379,http://192.168.2.210:4001 isLeader=false
e4a3e95f72ced4a7: name=etcd2 peerURLs=http://192.168.2.211:2380 clientURLs=http://192.168.2.211:2379,http://192.168.2.211:4001 isLeader=true

参考文档





####################

在k8s集群中使用了etcd作为数据中心，在实际操作中遇到了一些坑。今天记录一下，为了以后更好操作。
ETCD参数说明

    —data-dir 指定节点的数据存储目录，这些数据包括节点ID，集群ID，集群初始化配置，Snapshot文件，若未指定—wal-dir，还会存储WAL文件；
    —wal-dir 指定节点的was文件的存储目录，若指定了该参数，wal文件会和其他数据文件分开存储。
    —name 节点名称
    —initial-advertise-peer-urls 告知集群其他节点url.
    — listen-peer-urls 监听URL，用于与其他节点通讯
    — advertise-client-urls 告知客户端url, 也就是服务的url
    — initial-cluster-token 集群的ID
    — initial-cluster 集群中所有节点

 
节点迁移

在生产环境中，不可避免遇到机器硬件故障。当遇到硬件故障发生的时候，我们需要快速恢复节点。ETCD集群可以做到在不丢失数据的，
并且不改变节点ID的情况下，迁移节点。
具体办法是：

        1）停止待迁移节点上的etc进程；
        2）将数据目录打包复制到新的节点；
        3）更新该节点对应集群中peer url，让其指向新的节点；
        4）使用相同的配置，在新的节点上启动etcd进程
        etcd配置
        node1

        编辑etcd启动脚本/usr/local/etcd/start.sh

        /usr/local/etcd/etcd -name niub1 -debug \
        -initial-advertise-peer-urls http://niub-etcd-1:2380 \
        -listen-peer-urls http://niub-etcd-1:2380 \
        -listen-client-urls http://niub-etcd-1:2379,http://127.0.0.1:2379 \
        -advertise-client-urls http://niub-etcd-1:2379 \
        -initial-cluster-token etcd-cluster-1 \
        -initial-cluster niub1=http://niub-etcd-1:2380,niub2=http://niub-etcd-2:2380,niub3=http://niub-etcd-3:2380 \
        -initial-cluster-state new  >> /niub/etcd_log/etcd.log 2>&1 &

        node2

        编辑etcd启动脚本/usr/local/etcd/start.sh

        /usr/local/etcd/etcd -name niub2 -debug \
        -initial-advertise-peer-urls http://niub-etcd-2:2380 \
        -listen-peer-urls http://niub-etcd-2:2380 \
        -listen-client-urls http://niub-etcd-2:2379,http://127.0.0.1:2379 \
        -advertise-client-urls http://niub-etcd-2:2379 \
        -initial-cluster-token etcd-cluster-1 \
        -initial-cluster niub1=http://niub-etcd-1:2380,niub2=http://niub-etcd-2:2380,niub3=http://niub-etcd-3:2380 \
        -initial-cluster-state new  >> /niub/etcd_log/etcd.log 2>&1 &

        node3

        编辑etcd启动脚本/usr/local/etcd/start.sh

        /usr/local/etcd/etcd -name niub3 -debug \
        -initial-advertise-peer-urls http://niub-etcd-3:2380 \
        -listen-peer-urls http://niub-etcd-3:2380 \
        -listen-client-urls http://niub-etcd-3:2379,http://127.0.0.1:2379 \
        -advertise-client-urls http://niub-etcd-3:2379 \
        -initial-cluster-token etcd-cluster-1 \
        -initial-cluster niub1=http://niub-etcd-1:2380,niub2=http://niub-etcd-2:2380,niub3=http://niub-etcd-3:2380 \
        -initial-cluster-state new  >> /niub/etcd_log/etcd.log 2>&1 &

        防火墙

        在这3台node服务器开放2379、2380端口，命令：

        iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 2379 -j ACCEPT
        iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 2380 -j ACCEPT

        haproxy配置

        haproxy配置过程略 编辑/etc/haproxy/haproxy.cfg文件，增加：

        frontend etcd
            bind 10.10.0.14:2379
            mode tcp
            option tcplog
            default_backend etcd
            log 127.0.0.1 local3
            backend etcd
            balance roundrobin
            fullconn 1024
            server etcd1 10.10.0.11:2379 check port 2379 inter 300 fall 3
            server etcd2 10.10.0.12:2379 check port 2379 inter 300 fall 3
            server etcd3 10.10.0.13:2379 check port 2379 inter 300 fall 3

 
检查etcd服务运行状态

使用curl访问：

curl http://10.10.0.14:2379/v2/members

返回以下结果为正常（3个节点）：

{
  "members": [
    {
      "id": "1f890e0c67371d24",
      "name": "niub1",
      "peerURLs": [
        "http://niub-etcd-1:2380"
      ],
      "clientURLs": [
        "http://niub-etcd-1:2379"
      ]
    },
    {
      "id": "b952ccccefdd8a93",
      "name": "niub3",
      "peerURLs": [
        "http://niub-etcd-3:2380"
      ],
      "clientURLs": [
        "http://niub-etcd-3:2379"
      ]
    },
    {
      "id": "d6dbdb24d5bfc20f",
      "name": "niub2",
      "peerURLs": [
        "http://niub-etcd-2:2380"
      ],
      "clientURLs": [
        "http://niub-etcd-2:2379"
      ]
    }
  ]
}

etcd备份

使用etcd自带命令etcdctl进行etc备份，脚本如下：

#!/bin/bash

date_time=`date +%Y%m%d`
etcdctl backup --data-dir /usr/local/etcd/niub3.etcd/ --backup-dir /niub/etcd_backup/${date_time}

find /niub/etcd_backup/ -ctime +7 -exec rm -r {} \;

etcdctl操作

 

 更新一个节点

如果你想更新一个节点的 IP(peerURLS)，首先你需要知道那个节点的 ID。你可以列出所有节点，找出对应节点的 ID。

$ etcdctl member list
6e3bd23ae5f1eae0: name=node2 peerURLs=http://localhost:23802 clientURLs=http://127.0.0.1:23792
924e2e83e93f2560: name=node3 peerURLs=http://localhost:23803 clientURLs=http://127.0.0.1:23793
a8266ecf031671f3: name=node1 peerURLs=http://localhost:23801 clientURLs=http://127.0.0.1:23791

在本例中，我们假设要更新 ID 为 a8266ecf031671f3 的节点的 peerURLs 为：http://10.0.1.10:2380

$ etcdctl member update a8266ecf031671f3 http://10.0.1.10:2380
Updated member with ID a8266ecf031671f3 in cluster

删除一个节点

假设我们要删除 ID 为 a8266ecf031671f3 的节点

$ etcdctl member remove a8266ecf031671f3
Removed member a8266ecf031671f3 from cluster

执行完后，目标节点会自动停止服务，并且打印一行日志：

etcd: this member has been permanently removed from the cluster. Exiting.

如果删除的是 leader 节点，则需要耗费额外的时间重新选举 leader。
增加一个新的节点

增加一个新的节点分为两步：

    通过 etcdctl 或对应的 API 注册新节点

    使用恰当的参数启动新节点

先看第一步，假设我们要新加的节点取名为 infra3, peerURLs 是 http://10.0.1.13:2380

$ etcdctl member add infra3 http://10.0.1.13:2380
added member 9bf1b35fc7761a23 to cluster

ETCD_NAME="infra3"
ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra3=http://10.0.1.13:2380"
ETCD_INITIAL_CLUSTER_STATE=existing

etcdctl 在注册完新节点后，会返回一段提示，包含3个环境变量。然后在第二部启动新节点的时候，带上这3个环境变量即可。

$ export ETCD_NAME="infra3"
$ export ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra3=http://10.0.1.13:2380"
$ export ETCD_INITIAL_CLUSTER_STATE=existing
$ etcd -listen-client-urls http://10.0.1.13:2379 -advertise-client-urls http://10.0.1.13:2379  -listen-peer-urls http://10.0.1.13:2380 -initial-advertise-peer-urls http://10.0.1.13:2380 -data-dir %data_dir%

etcd -listen-client-urls http://192.168.31.104:2379,http://127.0.0.1 -advertise-client-urls http://192.168.31.104:2379  -listen-peer-urls http://10.0.1.13:2380 -initial-advertise-peer-urls http://10.0.1.13:2380 -data-dir %data_dir%

(示例如下：
##########################################在三个节点上测试：

[root@k3 ~]# etcdctl member list
1e19931c2af12589: name=192.168.31.102 peerURLs=http://192.168.31.102:2380 clientURLs=http://192.168.31.102:2379 isLeader=true
291b0bcd9cf9a651: name=192.168.31.103 peerURLs=http://192.168.31.103:2380 clientURLs=http://192.168.31.103:2379 isLeader=false
7997145293f00a6e: name=192.168.31.104 peerURLs=http://192.168.31.104:2380 clientURLs=http://192.168.31.104:2379 isLeader=false
[root@k3 ~]# 
查看ID 删除一个节点 

etcdctl member xxxx  

删除成功，并且那个节点会直接退出服务。

增加一个新的节点：

[root@k2 kubernetes]# etcdctl member add 192.168.31.104 http://192.168.31.104:2380
Added member named 192.168.31.104 with ID 7997145293f00a6e to cluster

ETCD_NAME="192.168.31.104"
ETCD_INITIAL_CLUSTER="192.168.31.102=http://192.168.31.102:2380,192.168.31.103=http://192.168.31.103:2380,192.168.31.104=http://192.168.31.104:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
[root@k2 kubernetes]# 

先删除原来的数据！！ 
 [root@k4 ~]# rm -rf /var/lib/etcd/default.etcd/

[root@k4 ~]# 
 

注意：必须加 --data-dir /var/lib/etcd/default.etcd/  
否则报错退出 即使在配置文件中已经指出了位置

etcd --name 192.168.31.104 --initial-advertise-peer-urls http://192.168.31.104:2380 \
  --listen-peer-urls http://192.168.31.104:2380 \
  --listen-client-urls http://192.168.31.104:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://192.168.31.104:2379 \
  --initial-cluster 192.168.31.102=http://192.168.31.102:2380,192.168.31.103=http://192.168.31.103:2380,192.168.31.104=http://192.168.31.104:2380 \
  --initial-cluster-state existing  \
  --data-dir /var/lib/etcd/default.etcd/ 

####################################################

)


这样，新节点就会运行起来并且加入到已有的集群中了。

值得注意的是，如果原先的集群只有1个节点，在新节点成功启动之前，新集群并不能正确的形成。因为原先的单节点集群无法完成leader的选举。
直到新节点启动完，和原先的节点建立连接以后，新集群才能正确形成。

服务故障恢复

在使用etcd集群的过程中，有时会出现少量主机故障，这时我们需要对集群进行维护。然而，在现实情况下，还可能遇到由于严重的设备 或网络的故障，导致超过半数的节点无法正常工作。

在etcd集群无法提供正常的服务，我们需要用到一些备份和数据恢复的手段。etcd背后的raft，保证了集群的数据的一致性与稳定性。所以我们对etcd的恢复，更多的是恢复etcd的节点服务，并还原用户数据。

首先，从剩余的正常节点中选择一个正常的成员节点， 使用 etcdctl backup 命令备份etcd数据。

$ ./etcdctl backup --data-dir /var/lib/etcd -backup-dir /tmp/etcd_backup
$ tar -zcxf backup.etcd.tar.gz /tmp/etcd_backup

这个命令会将节点中的用户数据全部写入到指定的备份目录中，但是节点ID,集群ID等信息将会丢失， 并在恢复到目的节点时被重新。这样主要是防止原先的节点意外重新加入新的节点集群而导致数据混乱。

然后将Etcd数据恢复到新的集群的任意一个节点上， 使用 --force-new-cluster 参数启动Etcd服务。这个参数会重置集群ID和集群的所有成员信息，其中节点的监听地址会被重置为localhost:2379, 表示集群中只有一个节点。

$ tar -zxvf backup.etcd.tar.gz -C /var/lib/etcd
$ etcd --data-dir=/var/lib/etcd --force-new-cluster ...

启动完成单节点的etcd,可以先对数据的完整性进行验证， 确认无误后再通过Etcd API修改节点的监听地址，让它监听节点的外部IP地址，为增加其他节点做准备。例如：

用etcd命令找到当前节点的ID。

$ etcdctl member list 

98f0c6bf64240842: name=cd-2 peerURLs=http://127.0.0.1:2580 clientURLs=http://127.0.0.1:2579

由于etcdctl不具备修改成员节点参数的功能， 下面的操作要使用API来完成。

$ curl http://127.0.0.1:2579/v2/members/98f0c6bf64240842 -XPUT \
 -H "Content-Type:application/json" -d '{"peerURLs":["http://127.0.0.1:2580"]}'

注意，在Etcd文档中， 建议首先将集群恢复到一个临时的目录中，从临时目录启动etcd，验证新的数据正确完整后，停止etcd，在将数据恢复到正常的目录中。

最后，在完成第一个成员节点的启动后，可以通过集群扩展的方法使用 etcdctl member add 命令添加其他成员节点进来。

 
扩展etcd集群

在集群中的任何一台etcd节点上执行命令，将新节点注册到集群：
1
	
curl http://127.0.0.1:2379/v2/members -XPOST -H "Content-Type: application/json" -d '{"peerURLs": ["http://192.168.73.172:2380"]}'

在新节点上启动etcd容器，注意-initial-cluster-state参数为existing
1
 
	

/usr/local/etcd/etcd \

-name etcd03 \
-advertise-client-urls http://192.168.73.150:2379,http://192.168.73.150:4001 \
-listen-client-urls http://0.0.0.0:2379 \
-initial-advertise-peer-urls http://192.168.73.150:2380 \
-listen-peer-urls http://0.0.0.0:2380 \
-initial-cluster-token etcd-cluster \
-initial-cluster "etcd01=http://192.168.73.140:2380,etcd02=http://192.168.73.137:2380,etcd03=http://192.168.73.150:2380" \
-initial-cluster-state existing

任意节点执行健康检查：
1
2
3
4
	
[root@docker01 ~]# etcdctl cluster-health
member 2bd5fcc327f74dd5 is healthy: got healthy result from http://192.168.73.140:2379
member c8a9cac165026b12 is healthy: got healthy result from http://192.168.73.137:2379
cluster is healthy
Etcd数据迁移

 
数据迁移

在 gzns-inf-platform53.gzns.baidu.com 机器上运行着一个 etcd 服务器，其 data-dir 为 /var/lib/etcd/。我们要以 /var/lib/etcd 中的数据为基础，搭建一个包含三个节点的高可用的 etcd 集群，三个节点的主机名分别为：

gzns-inf-platform53.gzns.baidu.com gzns-inf-platform56.gzns.baidu.com gzns-inf-platform60.gzns.baidu.com

初始化一个新的集群

我们先分别在上述三个节点上创建 /home/work/etcd/data-dir/ 文件夹当作 etcd 集群每个节点的数据存放目录。然后以 gzns-inf-platform60.gzns.baidu.com 节点为起点创建一个单节点的 etcd 集群，启动脚本 force-start-etcd.sh 如下：


#!/bin/bash

# Don't start it unless etcd cluster has a heavily crash !

../bin/etcd --name etcd2 --data-dir /home/work/etcd/data-dir --advertise-client-urls http://gzns-inf-platform60.gzns.baidu.com:2379,http://gzns-inf-platform60.gzns.baidu.com:4001 --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 --initial-advertise-peer-urls http://gzns-inf-platform60.gzns.baidu.com:2380 --listen-peer-urls http://0.0.0.0:2380 --initial-cluster-token etcd-cluster-1 --initial-cluster etcd2=http://gzns-inf-platform60.gzns.baidu.com:2380 --force-new-cluster > ./log/etcd.log 2>&1

这一步的 --force-new-cluster 很重要，可能是为了抹除旧 etcd 的一些属性信息，从而能成功的创建一个单节点 etcd 的集群。

这时候通过

etcdctl member list

查看 peerURLs 指向的是不是 http://gzns-inf-platform60.gzns.baidu.com:2380 ? 如果不是，需要更新这个 etcd 的 peerURLs 的指向，否则这样在加入新的节点时会失败的。

我们手动更新这个 etcd 的 peerURLs 指向

etcdctl member update ce2a822cea30bfca http://gzns-inf-platform60.gzns.baidu.com:2380

添加etcd1成员

然后添加 gzns-inf-platform56.gzns.baidu.com 节点上的 etcd1 成员

etcdctl member add etcd1 http://gzns-inf-platform56.gzns.baidu.com:2380

注意要先添加 etcd1 成员后，再在 gzns-inf-platform56.gzns 机器上启动这个 etcd1 成员

这时候我们登陆上 gzns-inf-platform56.gzns.baidu.com 机器上启动这个 etcd1 实例，启动脚本 force-start-etcd.sh 如下：


#!/bin/bash

# Don't start it unless etcd cluster has a heavily crash !

../bin/etcd --name etcd1 --data-dir /home/work/etcd/data-dir --advertise-client-urls http://gzns-inf-platform56.gzns.baidu.com:2379,http://gzns-inf-platform56.gzns.baidu.com:4001 --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 --initial-advertise-peer-urls http://gzns-inf-platform56.gzns.baidu.com:2380 --listen-peer-urls http://0.0.0.0:2380 --initial-cluster-token etcd-cluster-1 --initial-cluster etcd2=http://gzns-inf-platform60.gzns.baidu.com:2380,etcd1=http://gzns-inf-platform56.gzns.baidu.com:2380 --initial-cluster-state existing > ./log/etcd.log 2>&1

注意在这个节点上我们先把 data-dir 文件夹中的数据删除（如果有内容的情况下），然后设置 --initial-cluster和 --initial-cluster-state。
添加 etcd0 成员

这时候我们可以通过

etcdctl member list

观察到我们新加入的节点了，然后我们再以类似的步骤添加第三个节点 gzns-inf-platform53.gzns.baidu.com上 的 etcd0 实例

etcdctl member add etcd0 http://gzns-inf-platform53.gzns.baidu.com:2380

然后登陆到 gzns-inf-platform53.gzns.baidu.com 机器上启动 etcd0 这个实例，启动脚本 force-start-etcd.sh 如下：


#!/bin/bash

# Don't start it unless etcd cluster has a heavily crash !

../bin/etcd --name etcd0 --data-dir /home/work/etcd/data-dir --advertise-client-urls http://gzns-inf-platform53.gzns.baidu.com:2379,http://gzns-inf-platform53.gzns.baidu.com:4001 --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 --initial-advertise-peer-urls http://gzns-inf-platform53.gzns.baidu.com:2380 --listen-peer-urls http://0.0.0.0:2380 --initial-cluster-token etcd-cluster-1 --initial-cluster etcd2=http://gzns-inf-platform60.gzns.baidu.com:2380,etcd1=http://gzns-inf-platform56.gzns.baidu.com:2380,etcd0=http://gzns-inf-platform53.gzns.baidu.com:2380 --initial-cluster-state existing > ./log/etcd.log 2>&1

过程同加入 etcd1 的过程相似，这样我们就可以把单节点的 etcd 数据迁移到一个包含三个 etcd 实例组成的集群上了。
大体思路

先通过 --force-new-cluster 强行拉起一个 etcd 集群，抹除了原有 data-dir 中原有集群的属性信息（内部猜测），然后通过加入新成员的方式扩展这个集群到指定的数目。
高可用etcd集群方式（可选择）

上面数据迁移的过程一般是在紧急的状态下才会进行的操作，这时候可能 etcd 已经停掉了，或者节点不可用了。在一般情况下如何搭建一个高可用的 etcd 集群呢，目前采用的方法是用 supervise 来监控每个节点的 etcd 进程。

在数据迁移的过程中，我们已经搭建好了一个包含三个节点的 etcd 集群了，这时候我们对其做一些改变，使用supervise 重新拉起这些进程。

首先登陆到 gzns-inf-platform60.gzns.baidu.com 节点上，kill 掉 etcd 进程，编写 etcd 的启动脚本 start-etcd.sh，其中 start-etcd.sh 的内容如下：


#!/bin/bash
../bin/etcd --name etcd2 --data-dir /home/work/etcd/data-dir --advertise-client-urls http://gzns-inf-platform60.gzns.baidu.com:2379,http://gzns-inf-platform60.gzns.baidu.com:4001 --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 --initial-advertise-peer-urls http://gzns-inf-platform60.gzns.baidu.com:2380 --listen-peer-urls http://0.0.0.0:2380 --initial-cluster-token etcd-cluster-1 --initial-cluster etcd2=http://gzns-inf-platform60.gzns.baidu.com:2380,etcd1=http://gzns-inf-platform56.gzns.baidu.com:2380,etcd0=http://gzns-inf-platform53.gzns.baidu.com:2380 --initial-cluster-state existing > ./log/etcd.log 2>&1

然后使用 supervise 执行 start-etcd.sh 这个脚本，使用 supervise 启动 start-etcd.sh 的启动脚本 etcd_control 如下：


#!/bin/sh

if [ $# -ne 1 ]; then
    echo "$0: start|stop"
fi


work_path=`dirname $0`
cd ${work_path}
work_path=`pwd`

supervise=${work_path}/supervise/bin/supervise64.etcd
mkdir -p ${work_path}/supervise/status/etcd


case "$1" in
start) 
    killall etcd supervise64.etcd
    ${supervise} -f "sh ./start-etcd.sh" \
        -F ${work_path}/supervise/conf/supervise.conf  \
        -p  ${work_path}/supervise/status/etcd
    echo "START etcd daemon ok!"
;;
stop)
    killall etcd supervise64.etcd
    if [ $? -ne 0 ] 
    then
        echo "STOP etcd daemon failed!"
        exit 1
    fi  
    echo "STOP etcd daemon ok!"

这里为什么不直接用 supervise 执行 etcd 这个命令呢，反而以一个 start-etcd.sh 脚本的形式启动这个 etcd 呢？原因在于我们需要将 etcd 的输出信息重定向到文件中，

如果直接在 supervise 的 command 进行重定向，将发生错误。

分别登陆到以下两台机器

    gzns-inf-platform56.gzns.baidu.com
    gzns-inf-platform53.gzns.baidu.com

上进行同样的操作，注意要针对每个节点的不同修改对应的etcd name 和 peerURLs 等。
常见问题

1、etcd 读取已有的 data-dir 数据而启动失败，常常表现为cluster id not match什么的

可能原因是新启动的 etcd 属性与之前的不同，可以尝 --force-new-cluster 选项的形式启动一个新的集群

2、etcd 集群搭建完成后，通过 kubectl get pods 等一些操作发生错误的情况

目前解决办法是重启一下 apiserver 进程

3、还是 etcd启动失败的错误，大多数情况下都是与data-dir 有关系，data-dir 中记录的信息与 etcd启动的选项所标识的信息不太匹配造成的

如果能通过修改启动参数解决这类错误就最好不过的了，非常情况下的解决办法：

    一种解决办法是删除data-dir文件
    一种方法是复制其他节点的data-dir中的内容，以此为基础上以 --force-new-cluster 的形式强行拉起一个，然后以添加新成员的方式恢复这个集群，这是目前的几种解决办法


########################## Clustering Guide
Clustering Guide
Overview

Starting an etcd cluster statically requires that each member knows another in the cluster. In a number of cases, the IPs of the cluster members may be unknown ahead of time. In these cases, the etcd cluster can be bootstrapped with the help of a discovery service.

Once an etcd cluster is up and running, adding or removing members is done via runtime reconfiguration. To better understand the design behind runtime reconfiguration, we suggest reading the runtime configuration design document.

This guide will cover the following mechanisms for bootstrapping an etcd cluster:

    Static
    etcd Discovery
    DNS Discovery

Each of the bootstrapping mechanisms will be used to create a three machine etcd cluster with the following details:
Name    Address     Hostname
infra0  10.0.1.10   infra0.example.com
infra1  10.0.1.11   infra1.example.com
infra2  10.0.1.12   infra2.example.com
Static

As we know the cluster members, their addresses and the size of the cluster before starting, we can use an offline bootstrap configuration by setting the initial-cluster flag. Each machine will get either the following environment variables or command line:

ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380"
ETCD_INITIAL_CLUSTER_STATE=new

--initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
--initial-cluster-state new

Note that the URLs specified in initial-cluster are the advertised peer URLs, i.e. they should match the value of initial-advertise-peer-urls on the respective nodes.

If spinning up multiple clusters (or creating and destroying a single cluster) with same configuration for testing purpose, it is highly recommended that each cluster is given a unique initial-cluster-token. By doing this, etcd can generate unique cluster IDs and member IDs for the clusters even if they otherwise have the exact same configuration. This can protect etcd from cross-cluster-interaction, which might corrupt the clusters.

etcd listens on listen-client-urls to accept client traffic. etcd member advertises the URLs specified in advertise-client-urls to other members, proxies, clients. Please make sure the advertise-client-urls are reachable from intended clients. A common mistake is setting advertise-client-urls to localhost or leave it as default if the remote clients should reach etcd.

On each machine, start etcd with these flags:

$ etcd --name infra0 --initial-advertise-peer-urls http://10.0.1.10:2380 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
  --initial-cluster-state new

$ etcd --name infra1 --initial-advertise-peer-urls http://10.0.1.11:2380 \
  --listen-peer-urls http://10.0.1.11:2380 \
  --listen-client-urls http://10.0.1.11:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.11:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
  --initial-cluster-state new

$ etcd --name infra2 --initial-advertise-peer-urls http://10.0.1.12:2380 \
  --listen-peer-urls http://10.0.1.12:2380 \
  --listen-client-urls http://10.0.1.12:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.12:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
  --initial-cluster-state new

The command line parameters starting with --initial-cluster will be ignored on subsequent runs of etcd. Feel free to remove the environment variables or command line flags after the initial bootstrap process. If the configuration needs changes later (for example, adding or removing members to/from the cluster), see the runtime configuration guide.
TLS

etcd supports encrypted communication through the TLS protocol. TLS channels can be used for encrypted internal cluster communication between peers as well as encrypted client traffic. This section provides examples for setting up a cluster with peer and client TLS. Additional information detailing etcd's TLS support can be found in the security guide.
Self-signed certificates

A cluster using self-signed certificates both encrypts traffic and authenticates its connections. To start a cluster with self-signed certificates, each cluster member should have a unique key pair (member.crt, member.key) signed by a shared cluster CA certificate (ca.crt) for both peer connections and client connections. Certificates may be generated by following the etcd TLS setup example.

On each machine, etcd would be started with these flags:

$ etcd --name infra0 --initial-advertise-peer-urls https://10.0.1.10:2380 \
  --listen-peer-urls https://10.0.1.10:2380 \
  --listen-client-urls https://10.0.1.10:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://10.0.1.10:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=https://10.0.1.10:2380,infra1=https://10.0.1.11:2380,infra2=https://10.0.1.12:2380 \
  --initial-cluster-state new \
  --client-cert-auth --trusted-ca-file=/path/to/ca-client.crt \
  --cert-file=/path/to/infra0-client.crt --key-file=/path/to/infra0-client.key \
  --peer-client-cert-auth --peer-trusted-ca-file=ca-peer.crt \
  --peer-cert-file=/path/to/infra0-peer.crt --peer-key-file=/path/to/infra0-peer.key

$ etcd --name infra1 --initial-advertise-peer-urls https://10.0.1.11:2380 \
  --listen-peer-urls https://10.0.1.11:2380 \
  --listen-client-urls https://10.0.1.11:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://10.0.1.11:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=https://10.0.1.10:2380,infra1=https://10.0.1.11:2380,infra2=https://10.0.1.12:2380 \
  --initial-cluster-state new \
  --client-cert-auth --trusted-ca-file=/path/to/ca-client.crt \
  --cert-file=/path/to/infra1-client.crt --key-file=/path/to/infra1-client.key \
  --peer-client-cert-auth --peer-trusted-ca-file=ca-peer.crt \
  --peer-cert-file=/path/to/infra1-peer.crt --peer-key-file=/path/to/infra1-peer.key

$ etcd --name infra2 --initial-advertise-peer-urls https://10.0.1.12:2380 \
  --listen-peer-urls https://10.0.1.12:2380 \
  --listen-client-urls https://10.0.1.12:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://10.0.1.12:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=https://10.0.1.10:2380,infra1=https://10.0.1.11:2380,infra2=https://10.0.1.12:2380 \
  --initial-cluster-state new \
  --client-cert-auth --trusted-ca-file=/path/to/ca-client.crt \
  --cert-file=/path/to/infra2-client.crt --key-file=/path/to/infra2-client.key \
  --peer-client-cert-auth --peer-trusted-ca-file=ca-peer.crt \
  --peer-cert-file=/path/to/infra2-peer.crt --peer-key-file=/path/to/infra2-peer.key

Automatic certificates

If the cluster needs encrypted communication but does not require authenticated connections, etcd can be configured to automatically generate its keys. On initialization, each member creates its own set of keys based on its advertised IP addresses and hosts.

On each machine, etcd would be started with these flags:

$ etcd --name infra0 --initial-advertise-peer-urls https://10.0.1.10:2380 \
  --listen-peer-urls https://10.0.1.10:2380 \
  --listen-client-urls https://10.0.1.10:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://10.0.1.10:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=https://10.0.1.10:2380,infra1=https://10.0.1.11:2380,infra2=https://10.0.1.12:2380 \
  --initial-cluster-state new \
  --auto-tls \
  --peer-auto-tls

$ etcd --name infra1 --initial-advertise-peer-urls https://10.0.1.11:2380 \
  --listen-peer-urls https://10.0.1.11:2380 \
  --listen-client-urls https://10.0.1.11:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://10.0.1.11:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=https://10.0.1.10:2380,infra1=https://10.0.1.11:2380,infra2=https://10.0.1.12:2380 \
  --initial-cluster-state new \
  --auto-tls \
  --peer-auto-tls

$ etcd --name infra2 --initial-advertise-peer-urls https://10.0.1.12:2380 \
  --listen-peer-urls https://10.0.1.12:2380 \
  --listen-client-urls https://10.0.1.12:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://10.0.1.12:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=https://10.0.1.10:2380,infra1=https://10.0.1.11:2380,infra2=https://10.0.1.12:2380 \
  --initial-cluster-state new \
  --auto-tls \
  --peer-auto-tls

Error cases

In the following example, we have not included our new host in the list of enumerated nodes. If this is a new cluster, the node must be added to the list of initial cluster members.

$ etcd --name infra1 --initial-advertise-peer-urls http://10.0.1.11:2380 \
  --listen-peer-urls https://10.0.1.11:2380 \
  --listen-client-urls http://10.0.1.11:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.11:2379 \
  --initial-cluster infra0=http://10.0.1.10:2380 \
  --initial-cluster-state new
etcd: infra1 not listed in the initial cluster config
exit 1

In this example, we are attempting to map a node (infra0) on a different address (127.0.0.1:2380) than its enumerated address in the cluster list (10.0.1.10:2380). If this node is to listen on multiple addresses, all addresses must be reflected in the "initial-cluster" configuration directive.

$ etcd --name infra0 --initial-advertise-peer-urls http://127.0.0.1:2380 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
  --initial-cluster-state=new
etcd: error setting up initial cluster: infra0 has different advertised URLs in the cluster and advertised peer URLs list
exit 1

If a peer is configured with a different set of configuration arguments and attempts to join this cluster, etcd will report a cluster ID mismatch will exit.

$ etcd --name infra3 --initial-advertise-peer-urls http://10.0.1.13:2380 \
  --listen-peer-urls http://10.0.1.13:2380 \
  --listen-client-urls http://10.0.1.13:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.13:2379 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra3=http://10.0.1.13:2380 \
  --initial-cluster-state=new
etcd: conflicting cluster ID to the target cluster (c6ab534d07e8fcc4 != bc25ea2a74fb18b0). Exiting.
exit 1

Discovery

In a number of cases, the IPs of the cluster peers may not be known ahead of time. This is common when utilizing cloud providers or when the network uses DHCP. In these cases, rather than specifying a static configuration, use an existing etcd cluster to bootstrap a new one. This process is called "discovery".

There two methods that can be used for discovery:

    etcd discovery service
    DNS SRV records

etcd discovery

To better understand the design of the discovery service protocol, we suggest reading the discovery service protocol documentation.
Lifetime of a discovery URL

A discovery URL identifies a unique etcd cluster. Instead of reusing an existing discovery URL, each etcd instance shares a new discovery URL to bootstrap the new cluster.

Moreover, discovery URLs should ONLY be used for the initial bootstrapping of a cluster. To change cluster membership after the cluster is already running, see the runtime reconfiguration guide.
Custom etcd discovery service

Discovery uses an existing cluster to bootstrap itself. If using a private etcd cluster, create a URL like so:

$ curl -X PUT https://myetcd.local/v2/keys/discovery/6c007a14875d53d9bf0ef5a6fc0257c817f0fb83/_config/size -d value=3

By setting the size key to the URL, a discovery URL is created with an expected cluster size of 3.

The URL to use in this case will be https://myetcd.local/v2/keys/discovery/6c007a14875d53d9bf0ef5a6fc0257c817f0fb83 and the etcd members will use the https://myetcd.local/v2/keys/discovery/6c007a14875d53d9bf0ef5a6fc0257c817f0fb83 directory for registration as they start.

Each member must have a different name flag specified. Hostname or machine-id can be a good choice. Or discovery will fail due to duplicated name.

Now we start etcd with those relevant flags for each member:

$ etcd --name infra0 --initial-advertise-peer-urls http://10.0.1.10:2380 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --discovery https://myetcd.local/v2/keys/discovery/6c007a14875d53d9bf0ef5a6fc0257c817f0fb83

$ etcd --name infra1 --initial-advertise-peer-urls http://10.0.1.11:2380 \
  --listen-peer-urls http://10.0.1.11:2380 \
  --listen-client-urls http://10.0.1.11:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.11:2379 \
  --discovery https://myetcd.local/v2/keys/discovery/6c007a14875d53d9bf0ef5a6fc0257c817f0fb83

$ etcd --name infra2 --initial-advertise-peer-urls http://10.0.1.12:2380 \
  --listen-peer-urls http://10.0.1.12:2380 \
  --listen-client-urls http://10.0.1.12:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.12:2379 \
  --discovery https://myetcd.local/v2/keys/discovery/6c007a14875d53d9bf0ef5a6fc0257c817f0fb83

This will cause each member to register itself with the custom etcd discovery service and begin the cluster once all machines have been registered.
Public etcd discovery service

If no exiting cluster is available, use the public discovery service hosted at discovery.etcd.io. To create a private discovery URL using the "new" endpoint, use the command:

$ curl https://discovery.etcd.io/new?size=3
https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de

This will create the cluster with an initial size of 3 members. If no size is specified, a default of 3 is used.

ETCD_DISCOVERY=https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de

--discovery https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de

Each member must have a different name flag specified or else discovery will fail due to duplicated names. Hostname or machine-id can be a good choice.

Now we start etcd with those relevant flags for each member:

$ etcd --name infra0 --initial-advertise-peer-urls http://10.0.1.10:2380 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --discovery https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de

$ etcd --name infra1 --initial-advertise-peer-urls http://10.0.1.11:2380 \
  --listen-peer-urls http://10.0.1.11:2380 \
  --listen-client-urls http://10.0.1.11:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.11:2379 \
  --discovery https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de

$ etcd --name infra2 --initial-advertise-peer-urls http://10.0.1.12:2380 \
  --listen-peer-urls http://10.0.1.12:2380 \
  --listen-client-urls http://10.0.1.12:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.12:2379 \
  --discovery https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de

This will cause each member to register itself with the discovery service and begin the cluster once all members have been registered.

Use the environment variable ETCD_DISCOVERY_PROXY to cause etcd to use an HTTP proxy to connect to the discovery service.
Error and warning cases
Discovery server errors

$ etcd --name infra0 --initial-advertise-peer-urls http://10.0.1.10:2380 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --discovery https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de
etcd: error: the cluster doesn’t have a size configuration value in https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de/_config
exit 1

Warnings

This is a harmless warning indicating the discovery URL will be ignored on this machine.

$ etcd --name infra0 --initial-advertise-peer-urls http://10.0.1.10:2380 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --discovery https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de
etcdserver: discovery token ignored since a cluster has already been initialized. Valid log found at /var/lib/etcd

DNS discovery

DNS SRV records can be used as a discovery mechanism. The -discovery-srv flag can be used to set the DNS domain name where the discovery SRV records can be found. The following DNS SRV records are looked up in the listed order:

    _etcd-server-ssl._tcp.example.com
    _etcd-server._tcp.example.com

If _etcd-server-ssl._tcp.example.com is found then etcd will attempt the bootstrapping process over TLS.

To help clients discover the etcd cluster, the following DNS SRV records are looked up in the listed order:

    _etcd-client._tcp.example.com
    _etcd-client-ssl._tcp.example.com

If _etcd-client-ssl._tcp.example.com is found, clients will attempt to communicate with the etcd cluster over SSL/TLS.

If etcd is using TLS without a custom certificate authority, the discovery domain (e.g., example.com) must match the SRV record domain (e.g., infra1.example.com). This is to mitigate attacks that forge SRV records to point to a different domain; the domain would have a valid certificate under PKI but be controlled by an unknown third party.

The -discovery-srv-name flag additionally configures a suffix to the SRV name that is queried during discovery. Use this flag to differentiate between multiple etcd clusters under the same domain. For example, if discovery-srv=example.com and -discovery-srv-name=foo are set, the following DNS SRV queries are made:

    _etcd-server-ssl-foo._tcp.example.com
    _etcd-server-foo._tcp.example.com

Create DNS SRV records

$ dig +noall +answer SRV _etcd-server._tcp.example.com
_etcd-server._tcp.example.com. 300 IN  SRV  0 0 2380 infra0.example.com.
_etcd-server._tcp.example.com. 300 IN  SRV  0 0 2380 infra1.example.com.
_etcd-server._tcp.example.com. 300 IN  SRV  0 0 2380 infra2.example.com.

$ dig +noall +answer SRV _etcd-client._tcp.example.com
_etcd-client._tcp.example.com. 300 IN SRV 0 0 2379 infra0.example.com.
_etcd-client._tcp.example.com. 300 IN SRV 0 0 2379 infra1.example.com.
_etcd-client._tcp.example.com. 300 IN SRV 0 0 2379 infra2.example.com.

$ dig +noall +answer infra0.example.com infra1.example.com infra2.example.com
infra0.example.com.  300  IN  A  10.0.1.10
infra1.example.com.  300  IN  A  10.0.1.11
infra2.example.com.  300  IN  A  10.0.1.12

Bootstrap the etcd cluster using DNS

etcd cluster members can advertise domain names or IP address, the bootstrap process will resolve DNS A records. Since 3.2 (3.1 prints warnings) --listen-peer-urls and --listen-client-urls will reject domain name for the network interface binding.

The resolved address in --initial-advertise-peer-urls must match one of the resolved addresses in the SRV targets. The etcd member reads the resolved address to find out if it belongs to the cluster defined in the SRV records.

$ etcd --name infra0 \
--discovery-srv example.com \
--initial-advertise-peer-urls http://infra0.example.com:2380 \
--initial-cluster-token etcd-cluster-1 \
--initial-cluster-state new \
--advertise-client-urls http://infra0.example.com:2379 \
--listen-client-urls http://0.0.0.0:2379 \
--listen-peer-urls http://0.0.0.0:2380

$ etcd --name infra1 \
--discovery-srv example.com \
--initial-advertise-peer-urls http://infra1.example.com:2380 \
--initial-cluster-token etcd-cluster-1 \
--initial-cluster-state new \
--advertise-client-urls http://infra1.example.com:2379 \
--listen-client-urls http://0.0.0.0:2379 \
--listen-peer-urls http://0.0.0.0:2380

$ etcd --name infra2 \
--discovery-srv example.com \
--initial-advertise-peer-urls http://infra2.example.com:2380 \
--initial-cluster-token etcd-cluster-1 \
--initial-cluster-state new \
--advertise-client-urls http://infra2.example.com:2379 \
--listen-client-urls http://0.0.0.0:2379 \
--listen-peer-urls http://0.0.0.0:2380

The cluster can also bootstrap using IP addresses instead of domain names:

$ etcd --name infra0 \
--discovery-srv example.com \
--initial-advertise-peer-urls http://10.0.1.10:2380 \
--initial-cluster-token etcd-cluster-1 \
--initial-cluster-state new \
--advertise-client-urls http://10.0.1.10:2379 \
--listen-client-urls http://10.0.1.10:2379 \
--listen-peer-urls http://10.0.1.10:2380

$ etcd --name infra1 \
--discovery-srv example.com \
--initial-advertise-peer-urls http://10.0.1.11:2380 \
--initial-cluster-token etcd-cluster-1 \
--initial-cluster-state new \
--advertise-client-urls http://10.0.1.11:2379 \
--listen-client-urls http://10.0.1.11:2379 \
--listen-peer-urls http://10.0.1.11:2380

$ etcd --name infra2 \
--discovery-srv example.com \
--initial-advertise-peer-urls http://10.0.1.12:2380 \
--initial-cluster-token etcd-cluster-1 \
--initial-cluster-state new \
--advertise-client-urls http://10.0.1.12:2379 \
--listen-client-urls http://10.0.1.12:2379 \
--listen-peer-urls http://10.0.1.12:2380

Since v3.1.0 (except v3.2.9), when etcd --discovery-srv=example.com is configured with TLS, server will only authenticate peers/clients when the provided certs have root domain example.com as an entry in Subject Alternative Name (SAN) field. See Notes for DNS SRV.
Gateway

etcd gateway is a simple TCP proxy that forwards network data to the etcd cluster. Please read gateway guide for more information.
Proxy

When the --proxy flag is set, etcd runs in proxy mode. This proxy mode only supports the etcd v2 API; there are no plans to support the v3 API. Instead, for v3 API support, there will be a new proxy with enhanced features following the etcd 3.0 release.

To setup an etcd cluster with proxies of v2 API, please read the the clustering doc in etcd 2.3 release.



###############runtime configuration

Runtime reconfiguration

etcd comes with support for incremental runtime reconfiguration, which allows users to update the membership of the cluster at run time.

Reconfiguration requests can only be processed when a majority of cluster members are functioning. It is highly recommended to always have a cluster size greater than two in production. It is unsafe to remove a member from a two member cluster. The majority of a two member cluster is also two. If there is a failure during the removal process, the cluster might not be able to make progress and need to restart from majority failure.

To better understand the design behind runtime reconfiguration, please read the runtime reconfiguration document.
Reconfiguration use cases

This section will walk through some common reasons for reconfiguring a cluster. Most of these reasons just involve combinations of adding or removing a member, which are explained below under Cluster Reconfiguration Operations.
Cycle or upgrade multiple machines

If multiple cluster members need to move due to planned maintenance (hardware upgrades, network downtime, etc.), it is recommended to modify members one at a time.

It is safe to remove the leader, however there is a brief period of downtime while the election process takes place. If the cluster holds more than 50MB of v2 data, it is recommended to migrate the member's data directory.
Change the cluster size

Increasing the cluster size can enhance failure tolerance and provide better read performance. Since clients can read from any member, increasing the number of members increases the overall serialized read throughput.

Decreasing the cluster size can improve the write performance of a cluster, with a trade-off of decreased resilience. Writes into the cluster are replicated to a majority of members of the cluster before considered committed. Decreasing the cluster size lowers the majority, and each write is committed more quickly.
Replace a failed machine

If a machine fails due to hardware failure, data directory corruption, or some other fatal situation, it should be replaced as soon as possible. Machines that have failed but haven't been removed adversely affect the quorum and reduce the tolerance for an additional failure.

To replace the machine, follow the instructions for removing the member from the cluster, and then add a new member in its place. If the cluster holds more than 50MB, it is recommended to migrate the failed member's data directory if it is still accessible.
Restart cluster from majority failure

If the majority of the cluster is lost or all of the nodes have changed IP addresses, then manual action is necessary to recover safely. The basic steps in the recovery process include creating a new cluster using the old data, forcing a single member to act as the leader, and finally using runtime configuration to add new members to this new cluster one at a time.
Cluster reconfiguration operations

With these use cases in mind, the involved operations can be described for each.

Before making any change, a simple majority (quorum) of etcd members must be available. This is essentially the same requirement for any kind of write to etcd.

All changes to the cluster must be done sequentially:

    To update a single member peerURLs, issue an update operation
    To replace a healthy single member, remove the old member then add a new member
    To increase from 3 to 5 members, issue two add operations
    To decrease from 5 to 3, issue two remove operations

All of these examples use the etcdctl command line tool that ships with etcd. To change membership without etcdctl, use the v2 HTTP members API or the v3 gRPC members API.
Update a member
Update advertise client URLs

To update the advertise client URLs of a member, simply restart that member with updated client urls flag (--advertise-client-urls) or environment variable (ETCD_ADVERTISE_CLIENT_URLS). The restarted member will self publish the updated URLs. A wrongly updated client URL will not affect the health of the etcd cluster.
Update advertise peer URLs

To update the advertise peer URLs of a member, first update it explicitly via member command and then restart the member. The additional action is required since updating peer URLs changes the cluster wide configuration and can affect the health of the etcd cluster.

To update the advertise peer URLs, first find the target member's ID. To list all members with etcdctl:

$ etcdctl member list
6e3bd23ae5f1eae0: name=node2 peerURLs=http://localhost:23802 clientURLs=http://127.0.0.1:23792
924e2e83e93f2560: name=node3 peerURLs=http://localhost:23803 clientURLs=http://127.0.0.1:23793
a8266ecf031671f3: name=node1 peerURLs=http://localhost:23801 clientURLs=http://127.0.0.1:23791

This example will update a8266ecf031671f3 member ID and change its peerURLs value to http://10.0.1.10:2380:

$ etcdctl member update a8266ecf031671f3 --peer-urls=http://10.0.1.10:2380
Updated member with ID a8266ecf031671f3 in cluster

Remove a member

Suppose the member ID to remove is a8266ecf031671f3. Use the remove command to perform the removal:

$ etcdctl member remove a8266ecf031671f3
Removed member a8266ecf031671f3 from cluster

The target member will stop itself at this point and print out the removal in the log:

etcd: this member has been permanently removed from the cluster. Exiting.

It is safe to remove the leader, however the cluster will be inactive while a new leader is elected. This duration is normally the period of election timeout plus the voting process.
Add a new member

Adding a member is a two step process:

    Add the new member to the cluster via the HTTP members API, the gRPC members API, or the etcdctl member add command.
    Start the new member with the new cluster configuration, including a list of the updated members (existing members + the new member).

etcdctl adds a new member to the cluster by specifying the member's name and advertised peer URLs:

$ etcdctl member add infra3 http://10.0.1.13:2380
added member 9bf1b35fc7761a23 to cluster

ETCD_NAME="infra3"
ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra3=http://10.0.1.13:2380"
ETCD_INITIAL_CLUSTER_STATE=existing

etcdctl has informed the cluster about the new member and printed out the environment variables needed to successfully start it. Now start the new etcd process with the relevant flags for the new member:

$ export ETCD_NAME="infra3"
$ export ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra3=http://10.0.1.13:2380"
$ export ETCD_INITIAL_CLUSTER_STATE=existing
$ etcd --listen-client-urls http://10.0.1.13:2379 --advertise-client-urls http://10.0.1.13:2379 --listen-peer-urls http://10.0.1.13:2380 --initial-advertise-peer-urls http://10.0.1.13:2380 --data-dir %data_dir%

The new member will run as a part of the cluster and immediately begin catching up with the rest of the cluster.

If adding multiple members the best practice is to configure a single member at a time and verify it starts correctly before adding more new members. If adding a new member to a 1-node cluster, the cluster cannot make progress before the new member starts because it needs two members as majority to agree on the consensus. This behavior only happens between the time etcdctl member add informs the cluster about the new member and the new member successfully establishing a connection to the existing one.
Error cases when adding members

In the following case a new host is not included in the list of enumerated nodes. If this is a new cluster, the node must be added to the list of initial cluster members.

$ etcd --name infra3 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
  --initial-cluster-state existing
etcdserver: assign ids error: the member count is unequal
exit 1

In this case, give a different address (10.0.1.14:2380) from the one used to join the cluster (10.0.1.13:2380):

$ etcd --name infra4 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra4=http://10.0.1.14:2380 \
  --initial-cluster-state existing
etcdserver: assign ids error: unmatched member while checking PeerURLs
exit 1

If etcd starts using the data directory of a removed member, etcd automatically exits if it connects to any active member in the cluster:

$ etcd
etcd: this member has been permanently removed from the cluster. Exiting.
exit 1

Strict reconfiguration check mode (-strict-reconfig-check)

As described in the above, the best practice of adding new members is to configure a single member at a time and verify it starts correctly before adding more new members. This step by step approach is very important because if newly added members is not configured correctly (for example the peer URLs are incorrect), the cluster can lose quorum. The quorum loss happens since the newly added member are counted in the quorum even if that member is not reachable from other existing members. Also quorum loss might happen if there is a connectivity issue or there are operational issues.

For avoiding this problem, etcd provides an option -strict-reconfig-check. If this option is passed to etcd, etcd rejects reconfiguration requests if the number of started members will be less than a quorum of the reconfigured cluster.

It is enabled by default.



#######################
Disaster recovery

etcd is designed to withstand machine failures. An etcd cluster automatically recovers from temporary failures (e.g., machine reboots) and tolerates up to (N-1)/2 permanent failures for a cluster of N members. When a member permanently fails, whether due to hardware failure or disk corruption, it loses access to the cluster. If the cluster permanently loses more than (N-1)/2 members then it disastrously fails, irrevocably losing quorum. Once quorum is lost, the cluster cannot reach consensus and therefore cannot continue accepting updates.

To recover from disastrous failure, etcd v3 provides snapshot and restore facilities to recreate the cluster without v3 key data loss. To recover v2 keys, refer to the v2 admin guide.
Snapshotting the keyspace

Recovering a cluster first needs a snapshot of the keyspace from an etcd member. A snapshot may either be taken from a live member with the etcdctl snapshot save command or by copying the member/snap/db file from an etcd data directory. For example, the following command snapshots the keyspace served by $ENDPOINT to the file snapshot.db:

$ ETCDCTL_API=3 etcdctl --endpoints $ENDPOINT snapshot save snapshot.db

Restoring a cluster

To restore a cluster, all that is needed is a single snapshot "db" file. A cluster restore with etcdctl snapshot restore creates new etcd data directories; all members should restore using the same snapshot. Restoring overwrites some snapshot metadata (specifically, the member ID and cluster ID); the member loses its former identity. This metadata overwrite prevents the new member from inadvertently joining an existing cluster. Therefore in order to start a cluster from a snapshot, the restore must start a new logical cluster.

Snapshot integrity may be optionally verified at restore time. If the snapshot is taken with etcdctl snapshot save, it will have an integrity hash that is checked by etcdctl snapshot restore. If the snapshot is copied from the data directory, there is no integrity hash and it will only restore by using --skip-hash-check.

A restore initializes a new member of a new cluster, with a fresh cluster configuration using etcd's cluster configuration flags, but preserves the contents of the etcd keyspace. Continuing from the previous example, the following creates new etcd data directories (m1.etcd, m2.etcd, m3.etcd) for a three member cluster:

$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m1 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host1:2380
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m2 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host2:2380
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m3 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host3:2380

Next, start etcd with the new data directories:

$ etcd \
  --name m1 \
  --listen-client-urls http://host1:2379 \
  --advertise-client-urls http://host1:2379 \
  --listen-peer-urls http://host1:2380 &
$ etcd \
  --name m2 \
  --listen-client-urls http://host2:2379 \
  --advertise-client-urls http://host2:2379 \
  --listen-peer-urls http://host2:2380 &
$ etcd \
  --name m3 \
  --listen-client-urls http://host3:2379 \
  --advertise-client-urls http://host3:2379 \
  --listen-peer-urls http://host3:2380 &

Now the restored etcd cluster should be available and serving the keyspace given by the snapshot.
Restoring a cluster from membership mis-reconfiguration with wrong URLs

Previously, etcd panics on membership mis-reconfiguration with wrong URLs (v3.2.15 or later returns error early in client-side before etcd server panic).

Recommended way is restore from snapshot. --force-new-cluster can be used to overwrite cluster membership while keeping existing application data, but is strongly discouraged because it will panic if other members from previous cluster are still alive. Make sure to save snapshot periodically.



##############操作：
[root@k2 member]# etcdctl member list
1e19931c2af12589: name=192.168.31.102 peerURLs=http://192.168.31.102:2380 clientURLs=http://192.168.31.102:2379 isLeader=false
291b0bcd9cf9a651: name=192.168.31.103 peerURLs=http://192.168.31.103:2380 clientURLs=http://192.168.31.103:2379 isLeader=true
[root@k2 member]# etcdctl member add 192.168.31.104 http://192.168.31.104:2380
Added member named 192.168.31.104 with ID 37bdd14ba4d61b69 to cluster

ETCD_NAME="192.168.31.104"
ETCD_INITIAL_CLUSTER="192.168.31.102=http://192.168.31.102:2380,192.168.31.103=http://192.168.31.103:2380,192.168.31.104=http://192.168.31.104:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
[root@k2 member]# etcdctl  member list
1e19931c2af12589: name=192.168.31.102 peerURLs=http://192.168.31.102:2380 clientURLs=http://192.168.31.102:2379 isLeader=false
291b0bcd9cf9a651: name=192.168.31.103 peerURLs=http://192.168.31.103:2380 clientURLs=http://192.168.31.103:2379 isLeader=true
37bdd14ba4d61b69[unstarted]: peerURLs=http://192.168.31.104:2380


[root@k4 ~]export ETCD_NAME="192.168.31.104"
[root@k4 ~]export ETCD_INITIAL_CLUSTER="192.168.31.102=http://192.168.31.102:2380,192.168.31.103=http://192.168.31.103:2380,192.168.31.104=http://192.168.31.104:2380"
[root@k4 ~]export ETCD_INITIAL_CLUSTER_STATE="existing"

[root@k4 ~]# etcd --listen-client-urls http://192.168.31.104:2379 --advertise-client-urls http://192.168.31.104:2379 --listen-peer-urls http://192.168.31.104:2380  --initial-advertise-peer-urls http://192.168.31.104:2380 
2018-06-19 14:22:03.410061 I | pkg/flags: recognized and used environment variable ETCD_INITIAL_CLUSTER=192.168.31.102=http://192.168.31.102:2380,192.168.31.103=http://192.168.31.103:2380,192.168.31.104=http://192.168.31.104:2380
2018-06-19 14:22:03.410339 I | pkg/flags: recognized and used environment variable ETCD_INITIAL_CLUSTER_STATE=existing
2018-06-19 14:22:03.410373 I | pkg/flags: recognized and used environment variable ETCD_NAME=192.168.31.104
2018-06-19 14:22:03.410660 I | etcdmain: etcd Version: 3.2.18
2018-06-19 14:22:03.410702 I | etcdmain: Git SHA: eddf599
2018-06-19 14:22:03.410721 I | etcdmain: Go Version: go1.9.4
2018-06-19 14:22:03.410738 I | etcdmain: Go OS/Arch: linux/amd64
2018-06-19 14:22:03.410756 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2018-06-19 14:22:03.410832 W | etcdmain: no data-dir provided, using default data-dir ./192.168.31.104.etcd
2018-06-19 14:22:03.411245 I | embed: listening for peers on http://192.168.31.104:2380
2018-06-19 14:22:03.411518 I | embed: listening for client requests on 192.168.31.104:2379
2018-06-19 14:22:03.538866 I | etcdserver: name = 192.168.31.104
2018-06-19 14:22:03.539180 I | etcdserver: data dir = 192.168.31.104.etcd
2018-06-19 14:22:03.539215 I | etcdserver: member dir = 192.168.31.104.etcd/member
2018-06-19 14:22:03.539234 I | etcdserver: heartbeat = 100ms
2018-06-19 14:22:03.539251 I | etcdserver: election = 1000ms
2018-06-19 14:22:03.539268 I | etcdserver: snapshot count = 100000
2018-06-19 14:22:03.601446 I | etcdserver: advertise client URLs = http://192.168.31.104:2379
2018-06-19 14:22:03.654362 I | etcdserver: starting member 37bdd14ba4d61b69 in cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:03.654603 I | raft: 37bdd14ba4d61b69 became follower at term 0
2018-06-19 14:22:03.654677 I | raft: newRaft 37bdd14ba4d61b69 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
2018-06-19 14:22:03.654698 I | raft: 37bdd14ba4d61b69 became follower at term 1
2018-06-19 14:22:03.703729 W | auth: simple token is not cryptographically signed
2018-06-19 14:22:03.719588 I | rafthttp: started HTTP pipelining with peer 1e19931c2af12589
2018-06-19 14:22:03.719729 I | rafthttp: started HTTP pipelining with peer 291b0bcd9cf9a651
2018-06-19 14:22:03.719797 I | rafthttp: starting peer 1e19931c2af12589...
2018-06-19 14:22:03.719840 I | rafthttp: started HTTP pipelining with peer 1e19931c2af12589
2018-06-19 14:22:03.723079 I | rafthttp: started streaming with peer 1e19931c2af12589 (writer)
2018-06-19 14:22:03.724131 I | rafthttp: started streaming with peer 1e19931c2af12589 (writer)
2018-06-19 14:22:03.799186 I | rafthttp: started peer 1e19931c2af12589
2018-06-19 14:22:03.799310 I | rafthttp: added peer 1e19931c2af12589
2018-06-19 14:22:03.799375 I | rafthttp: starting peer 291b0bcd9cf9a651...
2018-06-19 14:22:03.799411 I | rafthttp: started HTTP pipelining with peer 291b0bcd9cf9a651
2018-06-19 14:22:03.830515 I | rafthttp: started streaming with peer 1e19931c2af12589 (stream MsgApp v2 reader)
2018-06-19 14:22:03.830702 I | rafthttp: started streaming with peer 291b0bcd9cf9a651 (stream Message reader)
2018-06-19 14:22:03.832900 I | rafthttp: started streaming with peer 1e19931c2af12589 (stream Message reader)
2018-06-19 14:22:03.833279 I | rafthttp: started streaming with peer 291b0bcd9cf9a651 (stream MsgApp v2 reader)
2018-06-19 14:22:03.834138 I | rafthttp: started peer 291b0bcd9cf9a651
2018-06-19 14:22:03.834346 I | rafthttp: added peer 291b0bcd9cf9a651
2018-06-19 14:22:03.834436 I | etcdserver: starting server... [version: 3.2.18, cluster version: to_be_decided]
2018-06-19 14:22:03.872461 I | rafthttp: started streaming with peer 291b0bcd9cf9a651 (writer)
2018-06-19 14:22:03.872543 I | rafthttp: started streaming with peer 291b0bcd9cf9a651 (writer)
2018-06-19 14:22:03.878161 I | raft: 37bdd14ba4d61b69 [term: 1] received a MsgHeartbeat message with higher term from 291b0bcd9cf9a651 [term: 19]
2018-06-19 14:22:03.878237 I | raft: 37bdd14ba4d61b69 became follower at term 19
2018-06-19 14:22:03.878290 I | raft: raft.node: 37bdd14ba4d61b69 elected leader 291b0bcd9cf9a651 at term 19
2018-06-19 14:22:03.878740 I | rafthttp: peer 291b0bcd9cf9a651 became active
2018-06-19 14:22:03.878773 I | rafthttp: established a TCP streaming connection with peer 291b0bcd9cf9a651 (stream Message writer)
2018-06-19 14:22:03.902925 I | rafthttp: peer 1e19931c2af12589 became active
2018-06-19 14:22:03.950827 I | rafthttp: established a TCP streaming connection with peer 291b0bcd9cf9a651 (stream MsgApp v2 writer)
2018-06-19 14:22:03.951081 I | rafthttp: established a TCP streaming connection with peer 1e19931c2af12589 (stream Message writer)
2018-06-19 14:22:04.057870 I | rafthttp: established a TCP streaming connection with peer 1e19931c2af12589 (stream MsgApp v2 reader)
2018-06-19 14:22:04.060365 I | rafthttp: established a TCP streaming connection with peer 1e19931c2af12589 (stream Message reader)
2018-06-19 14:22:04.060471 I | rafthttp: established a TCP streaming connection with peer 1e19931c2af12589 (stream MsgApp v2 writer)
2018-06-19 14:22:04.060845 I | rafthttp: established a TCP streaming connection with peer 291b0bcd9cf9a651 (stream MsgApp v2 reader)
2018-06-19 14:22:04.061312 I | rafthttp: established a TCP streaming connection with peer 291b0bcd9cf9a651 (stream Message reader)
2018-06-19 14:22:04.065741 I | etcdserver: 37bdd14ba4d61b69 initialzed peer connection; fast-forwarding 8 ticks (election ticks 10) with 2 active peer(s)
2018-06-19 14:22:04.144643 I | etcdserver/membership: added member 1e19931c2af12589 [http://192.168.31.102:2380] to cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:04.144957 I | etcdserver/membership: added member 291b0bcd9cf9a651 [http://192.168.31.103:2380] to cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:04.145109 I | etcdserver/membership: added member 726bc474d245d0e7 [http://192.168.31.104:2380] to cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:04.145161 I | rafthttp: starting peer 726bc474d245d0e7...
2018-06-19 14:22:04.145260 I | rafthttp: started HTTP pipelining with peer 726bc474d245d0e7
2018-06-19 14:22:04.146058 I | rafthttp: started streaming with peer 726bc474d245d0e7 (writer)
2018-06-19 14:22:04.146895 I | rafthttp: started streaming with peer 726bc474d245d0e7 (writer)
2018-06-19 14:22:04.147443 I | rafthttp: started peer 726bc474d245d0e7
2018-06-19 14:22:04.147620 I | rafthttp: started streaming with peer 726bc474d245d0e7 (stream MsgApp v2 reader)
2018-06-19 14:22:04.148229 I | rafthttp: added peer 726bc474d245d0e7
2018-06-19 14:22:04.152613 I | rafthttp: started streaming with peer 726bc474d245d0e7 (stream Message reader)
2018-06-19 14:22:04.154178 I | rafthttp: started HTTP pipelining with peer 37bdd14ba4d61b69
2018-06-19 14:22:04.154222 E | rafthttp: failed to find member 37bdd14ba4d61b69 in cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:04.154606 E | rafthttp: failed to find member 37bdd14ba4d61b69 in cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:04.187940 N | etcdserver/membership: set the initial cluster version to 3.0
2018-06-19 14:22:04.188384 I | etcdserver/api: enabled capabilities for version 3.0
2018-06-19 14:22:04.188511 N | etcdserver/membership: updated the cluster version from 3.0 to 3.2
2018-06-19 14:22:04.188612 I | etcdserver/api: enabled capabilities for version 3.2
2018-06-19 14:22:04.217796 I | etcdserver/membership: removed member 726bc474d245d0e7 from cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:04.217842 I | rafthttp: stopping peer 726bc474d245d0e7...
2018-06-19 14:22:04.217880 I | rafthttp: stopped streaming with peer 726bc474d245d0e7 (writer)
2018-06-19 14:22:04.217906 I | rafthttp: stopped streaming with peer 726bc474d245d0e7 (writer)
2018-06-19 14:22:04.217946 I | rafthttp: stopped HTTP pipelining with peer 726bc474d245d0e7
2018-06-19 14:22:04.218002 I | rafthttp: stopped streaming with peer 726bc474d245d0e7 (stream MsgApp v2 reader)
2018-06-19 14:22:04.218032 I | rafthttp: stopped streaming with peer 726bc474d245d0e7 (stream Message reader)
2018-06-19 14:22:04.218052 I | rafthttp: stopped peer 726bc474d245d0e7
2018-06-19 14:22:04.218081 I | rafthttp: removed peer 726bc474d245d0e7
2018-06-19 14:22:04.218220 I | etcdserver/membership: added member 37bdd14ba4d61b69 [http://192.168.31.104:2380] to cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:04.218385 I | etcdserver: published {Name:192.168.31.104 ClientURLs:[http://192.168.31.104:2379]} to cluster 6eb4bb0ca1c3b44e
2018-06-19 14:22:04.218606 E | etcdmain: forgot to set Type=notify in systemd service file?
2018-06-19 14:22:04.218804 I | embed: ready to serve client requests
2018-06-19 14:22:04.219866 N | embed: serving insecure client requests on 192.168.31.104:2379, this is strongly discouraged!

完成加入后，可以再查看成员：
[root@k2 member]# etcdctl member list
1e19931c2af12589: name=192.168.31.102 peerURLs=http://192.168.31.102:2380 clientURLs=http://192.168.31.102:2379 isLeader=false
291b0bcd9cf9a651: name=192.168.31.103 peerURLs=http://192.168.31.103:2380 clientURLs=http://192.168.31.103:2379 isLeader=true
37bdd14ba4d61b69: name=192.168.31.104 peerURLs=http://192.168.31.104:2380 clientURLs=http://192.168.31.104:2379 isLeader=false
[root@k2 member]#


注意：这里有一个坑，如果是这个主机停止后，再次加入的话，需要先删除 /var/lib/etcd/ 目录，然后重新运行命令
[root@k4 ~]# etcd --listen-client-urls http://192.168.31.104:2379 --advertise-client-urls http://192.168.31.104:2379 --listen-peer-urls http://192.168.31.104:2380 --initial-advertise-peer-urls http://192.168.31.104:2380 --data-dir /var/lib/etcd/default.etcd/
2018-06-19 14:51:54.018848 I | pkg/flags: recognized and used environment variable ETCD_INITIAL_CLUSTER=192.168.31.104=http://192.168.31.104:2380,192.168.31.102=http://192.168.31.102:2380,192.168.31.103=http://192.168.31.103:2380
2018-06-19 14:51:54.019130 I | pkg/flags: recognized and used environment variable ETCD_INITIAL_CLUSTER_STATE=existing
2018-06-19 14:51:54.019187 I | pkg/flags: recognized and used environment variable ETCD_NAME=192.168.31.104
2018-06-19 14:51:54.019379 I | etcdmain: etcd Version: 3.2.18
2018-06-19 14:51:54.019398 I | etcdmain: Git SHA: eddf599
2018-06-19 14:51:54.019414 I | etcdmain: Go Version: go1.9.4
2018-06-19 14:51:54.019431 I | etcdmain: Go OS/Arch: linux/amd64
2018-06-19 14:51:54.019449 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2018-06-19 14:51:54.019624 N | etcdmain: the server is already initialized as member before, starting as etcd member...
2018-06-19 14:51:54.020033 I | embed: listening for peers on http://192.168.31.104:2380
2018-06-19 14:51:54.020259 I | embed: listening for client requests on 192.168.31.104:2379
2018-06-19 14:51:54.070850 I | etcdserver: name = 192.168.31.104
2018-06-19 14:51:54.070911 I | etcdserver: data dir = /var/lib/etcd/default.etcd/
2018-06-19 14:51:54.070931 I | etcdserver: member dir = /var/lib/etcd/default.etcd/member
2018-06-19 14:51:54.070949 I | etcdserver: heartbeat = 100ms
2018-06-19 14:51:54.070967 I | etcdserver: election = 1000ms
2018-06-19 14:51:54.070984 I | etcdserver: snapshot count = 100000
2018-06-19 14:51:54.071019 I | etcdserver: advertise client URLs = http://192.168.31.104:2379
2018-06-19 14:51:54.167907 I | etcdserver: restarting member 726bc474d245d0e7 in cluster 6eb4bb0ca1c3b44e at commit index 15
2018-06-19 14:51:54.168186 I | raft: 726bc474d245d0e7 became follower at term 22
2018-06-19 14:51:54.168245 I | raft: newRaft 726bc474d245d0e7 [peers: [], term: 22, commit: 15, applied: 0, lastindex: 15, lastterm: 19]
2018-06-19 14:51:54.198647 W | auth: simple token is not cryptographically signed
2018-06-19 14:51:54.204042 I | etcdserver: starting server... [version: 3.2.18, cluster version: to_be_decided]
2018-06-19 14:51:54.224169 I | rafthttp: started HTTP pipelining with peer 1e19931c2af12589
2018-06-19 14:51:54.224323 E | rafthttp: failed to find member 1e19931c2af12589 in cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.224939 I | rafthttp: started HTTP pipelining with peer 291b0bcd9cf9a651
2018-06-19 14:51:54.224969 E | rafthttp: failed to find member 291b0bcd9cf9a651 in cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.225088 I | etcdserver/membership: added member 1e19931c2af12589 [http://192.168.31.102:2380] to cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.225211 I | rafthttp: starting peer 1e19931c2af12589...
2018-06-19 14:51:54.225287 I | rafthttp: started HTTP pipelining with peer 1e19931c2af12589
2018-06-19 14:51:54.231088 I | rafthttp: started streaming with peer 1e19931c2af12589 (writer)
2018-06-19 14:51:54.236225 I | raft: raft.node: 726bc474d245d0e7 elected leader 291b0bcd9cf9a651 at term 22
2018-06-19 14:51:54.253348 I | rafthttp: started streaming with peer 1e19931c2af12589 (writer)
2018-06-19 14:51:54.329080 I | rafthttp: started peer 1e19931c2af12589
2018-06-19 14:51:54.329194 I | rafthttp: added peer 1e19931c2af12589
2018-06-19 14:51:54.329275 I | rafthttp: started streaming with peer 1e19931c2af12589 (stream Message reader)
2018-06-19 14:51:54.329979 I | etcdserver/membership: added member 291b0bcd9cf9a651 [http://192.168.31.103:2380] to cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.330259 I | rafthttp: started streaming with peer 1e19931c2af12589 (stream MsgApp v2 reader)
2018-06-19 14:51:54.330291 E | rafthttp: streaming request ignored (ID mismatch got 101be1a4c9b57e75 want 726bc474d245d0e7)
2018-06-19 14:51:54.330652 I | rafthttp: starting peer 291b0bcd9cf9a651...
2018-06-19 14:51:54.330701 I | rafthttp: started HTTP pipelining with peer 291b0bcd9cf9a651
2018-06-19 14:51:54.386212 I | rafthttp: started streaming with peer 291b0bcd9cf9a651 (writer)
2018-06-19 14:51:54.404584 I | rafthttp: started peer 291b0bcd9cf9a651
2018-06-19 14:51:54.404653 I | rafthttp: added peer 291b0bcd9cf9a651
2018-06-19 14:51:54.404970 I | etcdserver/membership: added member 726bc474d245d0e7 [http://192.168.31.104:2380] to cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.405265 N | etcdserver/membership: set the initial cluster version to 3.0
2018-06-19 14:51:54.406820 I | etcdserver/api: enabled capabilities for version 3.0
2018-06-19 14:51:54.407037 N | etcdserver/membership: updated the cluster version from 3.0 to 3.2
2018-06-19 14:51:54.407185 I | etcdserver/api: enabled capabilities for version 3.2
2018-06-19 14:51:54.407586 I | etcdserver/membership: removed member 726bc474d245d0e7 from cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.407834 I | rafthttp: started streaming with peer 291b0bcd9cf9a651 (writer)
2018-06-19 14:51:54.407899 I | rafthttp: started streaming with peer 291b0bcd9cf9a651 (stream MsgApp v2 reader)
2018-06-19 14:51:54.408326 I | rafthttp: started streaming with peer 291b0bcd9cf9a651 (stream Message reader)
2018-06-19 14:51:54.408733 E | rafthttp: streaming request ignored (ID mismatch got 101be1a4c9b57e75 want 726bc474d245d0e7)
2018-06-19 14:51:54.408893 E | rafthttp: failed to find member 291b0bcd9cf9a651 in cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.439117 E | etcdserver: the member has been permanently removed from the cluster
2018-06-19 14:51:54.439305 I | etcdserver: the data-dir used by this member must be removed.
2018-06-19 14:51:54.439463 E | etcdserver: publish error: etcdserver: request cancelled
2018-06-19 14:51:54.439502 I | etcdserver: aborting publish because server is stopped
2018-06-19 14:51:54.439578 I | rafthttp: stopped HTTP pipelining with peer 1e19931c2af12589
2018-06-19 14:51:54.439802 I | rafthttp: stopped HTTP pipelining with peer 291b0bcd9cf9a651
2018-06-19 14:51:54.439828 I | rafthttp: stopping peer 1e19931c2af12589...
2018-06-19 14:51:54.439939 I | rafthttp: stopped streaming with peer 1e19931c2af12589 (writer)
2018-06-19 14:51:54.440255 I | rafthttp: stopped HTTP pipelining with peer 1e19931c2af12589
2018-06-19 14:51:54.440310 I | rafthttp: stopped streaming with peer 1e19931c2af12589 (stream MsgApp v2 reader)
2018-06-19 14:51:54.440351 I | rafthttp: stopped streaming with peer 1e19931c2af12589 (stream Message reader)
2018-06-19 14:51:54.440372 I | rafthttp: stopped peer 1e19931c2af12589
2018-06-19 14:51:54.440392 I | rafthttp: stopping peer 291b0bcd9cf9a651...
2018-06-19 14:51:54.440417 I | rafthttp: stopped streaming with peer 291b0bcd9cf9a651 (writer)
2018-06-19 14:51:54.440442 I | rafthttp: stopped streaming with peer 291b0bcd9cf9a651 (writer)
2018-06-19 14:51:54.443031 I | rafthttp: stopped HTTP pipelining with peer 291b0bcd9cf9a651
2018-06-19 14:51:54.443072 I | rafthttp: stopped streaming with peer 291b0bcd9cf9a651 (stream MsgApp v2 reader)
2018-06-19 14:51:54.443098 I | rafthttp: stopped streaming with peer 291b0bcd9cf9a651 (stream Message reader)
2018-06-19 14:51:54.443118 I | rafthttp: stopped peer 291b0bcd9cf9a651
2018-06-19 14:51:54.471825 E | rafthttp: failed to find member 1e19931c2af12589 in cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.474138 W | rafthttp: failed to process raft message (raft: stopped)
2018-06-19 14:51:54.585767 W | rafthttp: failed to process raft message (raft: stopped)
2018-06-19 14:51:54.588508 E | rafthttp: failed to find member 291b0bcd9cf9a651 in cluster 6eb4bb0ca1c3b44e
2018-06-19 14:51:54.590151 E | etcdmain: forgot to set Type=notify in systemd service file?

[root@k4 ~]# rm  -rf  /var/lib/etcd/default.etcd/
[root@k4 ~]# etcd --listen-client-urls http://192.168.31.104:2379 --advertise-client-urls http://192.168.31.104:2379 --listen-peer-urls http://192.168.31.104:2380 --initial-advertise-peer-urls http://192.168.31.104:2380 --data-dir /var/lib/etcd/default.etcd/

就正常了。
[root@k3 ~]# etcdctl member list
101be1a4c9b57e75: name=192.168.31.104 peerURLs=http://192.168.31.104:2380 clientURLs=http://192.168.31.104:2379 isLeader=false
1e19931c2af12589: name=192.168.31.102 peerURLs=http://192.168.31.102:2380 clientURLs=http://192.168.31.102:2379 isLeader=false
291b0bcd9cf9a651: name=192.168.31.103 peerURLs=http://192.168.31.103:2380 clientURLs=http://192.168.31.103:2379 isLeader=true
[root@k3 ~]# 



########################################management 

Administration
Data Directory
Lifecycle

When first started, etcd stores its configuration into a data directory specified by the data-dir configuration parameter. Configuration is stored in the write ahead log and includes: the local member ID, cluster ID, and initial cluster configuration. The write ahead log and snapshot files are used during member operation and to recover after a restart.

Having a dedicated disk to store wal files can improve the throughput and stabilize the cluster. It is highly recommended to dedicate a wal disk and set --wal-dir to point to a directory on that device for a production cluster deployment.

If a member’s data directory is ever lost or corrupted then the user should remove the etcd member from the cluster using etcdctl tool.

A user should avoid restarting an etcd member with a data directory from an out-of-date backup. Using an out-of-date data directory can lead to inconsistency as the member had agreed to store information via raft then re-joins saying it needs that information again. For maximum safety, if an etcd member suffers any sort of data corruption or loss, it must be removed from the cluster. Once removed the member can be re-added with an empty data directory.
Contents

The data directory has two sub-directories in it:

    wal: write ahead log files are stored here. For details see the wal package documentation
    snap: log snapshots are stored here. For details see the snap package documentation

If --wal-dir flag is set, etcd will write the write ahead log files to the specified directory instead of data directory.
Cluster Management
Lifecycle

If you are spinning up multiple clusters for testing it is recommended that you specify a unique initial-cluster-token for the different clusters. This can protect you from cluster corruption in case of mis-configuration because two members started with different cluster tokens will refuse members from each other.
Monitoring

It is important to monitor your production etcd cluster for healthy information and runtime metrics.
Health Monitoring

At lowest level, etcd exposes health information via HTTP at /health in JSON format. If it returns {"health":"true"}, then the cluster is healthy.

$ curl -L http://127.0.0.1:2379/health

{"health":"true"}

You can also use etcdctl to check the cluster-wide health information. It will contact all the members of the cluster and collect the health information for you.

$./etcdctl cluster-health
member 8211f1d0f64f3269 is healthy: got healthy result from http://127.0.0.1:12379
member 91bc3c398fb3c146 is healthy: got healthy result from http://127.0.0.1:22379
member fd422379fda50e48 is healthy: got healthy result from http://127.0.0.1:32379
cluster is healthy

Runtime Metrics

etcd uses Prometheus for metrics reporting in the server. You can read more through the runtime metrics doc.
Debugging

Debugging a distributed system can be difficult. etcd provides several ways to make debug easier.
Enabling Debug Logging

When you want to debug etcd without stopping it, you can enable debug logging at runtime. etcd exposes logging configuration at /config/local/log.

/config/local/log endpoint is being deprecated in v3.5.

$ curl http://127.0.0.1:2379/config/local/log -XPUT -d '{"Level":"DEBUG"}'
# debug logging enabled

$ curl http://127.0.0.1:2379/config/local/log -XPUT -d '{"Level":"INFO"}'
# debug logging disabled

Debugging Variables

Debug variables are exposed for real-time debugging purposes. Developers who are familiar with etcd can utilize these variables to debug unexpected behavior. etcd exposes debug variables via HTTP at /debug/vars in JSON format. The debug variables contains cmdline, file_descriptor_limit, memstats and raft.status.

cmdline is the command line arguments passed into etcd.

file_descriptor_limit is the max number of file descriptors etcd can utilize.

memstats is explained in detail in the Go runtime documentation.

raft.status is useful when you want to debug low level raft issues if you are familiar with raft internals. In most cases, you do not need to check raft.status.

{
"cmdline": ["./etcd"],
"file_descriptor_limit": 0,
"memstats": {"Alloc":4105744,"TotalAlloc":42337320,"Sys":12560632,"...":"..."},
"raft.status": {"id":"ce2a822cea30bfca","term":5,"vote":"ce2a822cea30bfca","commit":23509,"lead":"ce2a822cea30bfca","raftState":"StateLeader","progress":{"ce2a822cea30bfca":{"match":23509,"next":23510,"state":"ProgressStateProbe"}}}
}

Optimal Cluster Size

The recommended etcd cluster size is 3, 5 or 7, which is decided by the fault tolerance requirement. A 7-member cluster can provide enough fault tolerance in most cases. While larger cluster provides better fault tolerance the write performance reduces since data needs to be replicated to more machines.
Fault Tolerance Table

It is recommended to have an odd number of members in a cluster. Having an odd cluster size doesn't change the number needed for majority, but you gain a higher tolerance for failure by adding the extra member. You can see this in practice when comparing even and odd sized clusters:
Cluster Size    Majority    Failure Tolerance
1   1   0
2   2   0
3   2   1
4   3   1
5   3   2
6   4   2
7   4   3
8   5   3
9   5   4

As you can see, adding another member to bring the size of cluster up to an odd size is always worth it. During a network partition, an odd number of members also guarantees that there will almost always be a majority of the cluster that can continue to operate and be the source of truth when the partition ends.
Changing Cluster Size

After your cluster is up and running, adding or removing members is done via runtime reconfiguration, which allows the cluster to be modified without downtime. The etcdctl tool has member list, member add and member remove commands to complete this process.
Member Migration

When there is a scheduled machine maintenance or retirement, you might want to migrate an etcd member to another machine without losing the data and changing the member ID.

The data directory contains all the data to recover a member to its point-in-time state. To migrate a member:

    Stop the member process.
    Copy the data directory of the now-idle member to the new machine.
    Update the peer URLs for the replaced member to reflect the new machine according to the runtime reconfiguration instructions.
    Start etcd on the new machine, using the same configuration and the copy of the data directory.

This example will walk you through the process of migrating the infra1 member to a new machine:
Name    Peer URL
infra0  10.0.1.10:2380
infra1  10.0.1.11:2380
infra2  10.0.1.12:2380

$ export ETCDCTL_ENDPOINT=http://10.0.1.10:2379,http://10.0.1.11:2379,http://10.0.1.12:2379

$ etcdctl member list
84194f7c5edd8b37: name=infra0 peerURLs=http://10.0.1.10:2380 clientURLs=http://127.0.0.1:2379,http://10.0.1.10:2379
b4db3bf5e495e255: name=infra1 peerURLs=http://10.0.1.11:2380 clientURLs=http://127.0.0.1:2379,http://10.0.1.11:2379
bc1083c870280d44: name=infra2 peerURLs=http://10.0.1.12:2380 clientURLs=http://127.0.0.1:2379,http://10.0.1.12:2379

Stop the member etcd process

$ ssh 10.0.1.11

$ kill `pgrep etcd`

Copy the data directory of the now-idle member to the new machine

$ tar -cvzf infra1.etcd.tar.gz %data_dir%

$ scp infra1.etcd.tar.gz 10.0.1.13:~/

Update the peer URLs for that member to reflect the new machine

$ curl http://10.0.1.10:2379/v2/members/b4db3bf5e495e255 -XPUT \
-H "Content-Type: application/json" -d '{"peerURLs":["http://10.0.1.13:2380"]}'

Or use etcdctl member update command

$ etcdctl member update b4db3bf5e495e255 http://10.0.1.13:2380

Start etcd on the new machine, using the same configuration and the copy of the data directory

$ ssh 10.0.1.13

$ tar -xzvf infra1.etcd.tar.gz -C %data_dir%

etcd -name infra1 \
-listen-peer-urls http://10.0.1.13:2380 \
-listen-client-urls http://10.0.1.13:2379,http://127.0.0.1:2379 \
-advertise-client-urls http://10.0.1.13:2379,http://127.0.0.1:2379

Disaster Recovery

etcd is designed to be resilient to machine failures. An etcd cluster can automatically recover from any number of temporary failures (for example, machine reboots), and a cluster of N members can tolerate up to (N-1)/2 permanent failures (where a member can no longer access the cluster, due to hardware failure or disk corruption). However, in extreme circumstances, a cluster might permanently lose enough members such that quorum is irrevocably lost. For example, if a three-node cluster suffered two simultaneous and unrecoverable machine failures, it would be normally impossible for the cluster to restore quorum and continue functioning.

To recover from such scenarios, etcd provides functionality to backup and restore the datastore and recreate the cluster without data loss.
Backing up the datastore

Note: Windows users must stop etcd before running the backup command.

The first step of the recovery is to backup the data directory and wal directory, if stored separately, on a functioning etcd node. To do this, use the etcdctl backup command, passing in the original data (and wal) directory used by etcd. For example:

    etcdctl backup \
      --data-dir %data_dir% \
      [--wal-dir %wal_dir%] \
      --backup-dir %backup_data_dir%
      [--backup-wal-dir %backup_wal_dir%]

This command will rewrite some of the metadata contained in the backup (specifically, the node ID and cluster ID), which means that the node will lose its former identity. In order to recreate a cluster from the backup, you will need to start a new, single-node cluster. The metadata is rewritten to prevent the new node from inadvertently being joined onto an existing cluster.
Restoring a backup

To restore a backup using the procedure created above, start etcd with the -force-new-cluster option and pointing to the backup directory. This will initialize a new, single-member cluster with the default advertised peer URLs, but preserve the entire contents of the etcd data store. Continuing from the previous example:

    etcd \
      -data-dir=%backup_data_dir% \
      [-wal-dir=%backup_wal_dir%] \
      -force-new-cluster \
      ...

Now etcd should be available on this node and serving the original datastore.

Once you have verified that etcd has started successfully, shut it down and move the data and wal, if stored separately, back to the previous location (you may wish to make another copy as well to be safe):

    pkill etcd
    rm -fr %data_dir%
    rm -fr %wal_dir%
    mv %backup_data_dir% %data_dir%
    mv %backup_wal_dir% %wal_dir%
    etcd \
      -data-dir=%data_dir% \
      [-wal-dir=%wal_dir%] \
      ...

Restoring the cluster

Now that the node is running successfully, change its advertised peer URLs, as the --force-new-cluster option has set the peer URL to the default listening on localhost.

You can then add more nodes to the cluster and restore resiliency. See the add a new member guide for more details.

Note: If you are trying to restore your cluster using old failed etcd nodes, please make sure you have stopped old etcd instances and removed their old data directories specified by the data-dir configuration parameter.
Client Request Timeout

etcd sets different timeouts for various types of client requests. The timeout value is not tunable now, which will be improved soon (https://github.com/coreos/etcd/issues/2038).
Get requests

Timeout is not set for get requests, because etcd serves the result locally in a non-blocking way.

Note: QuorumGet request is a different type, which is mentioned in the following sections.
Watch requests

Timeout is not set for watch requests. etcd will not stop a watch request until client cancels it, or the connection is broken.
Delete, Put, Post, QuorumGet requests

The default timeout is 5 seconds. It should be large enough to allow all key modifications if the majority of cluster is functioning.

If the request times out, it indicates two possibilities:

    the server the request sent to was not functioning at that time.
    the majority of the cluster is not functioning.

If timeout happens several times continuously, administrators should check status of cluster and resolve it as soon as possible.
Best Practices
Maximum OS threads

By default, etcd uses the default configuration of the Go 1.4 runtime, which means that at most one operating system thread will be used to execute code simultaneously. (Note that this default behavior has changed in Go 1.5).

When using etcd in heavy-load scenarios on machines with multiple cores it will usually be desirable to increase the number of threads that etcd can utilize. To do this, simply set the environment variable GOMAXPROCS to the desired number when starting etcd. For more information on this variable, see the Go runtime documentation.



#################### 网络问题
Network

If the etcd leader serves a large number of concurrent client requests, it may delay processing follower peer requests due to network congestion. This manifests as send buffer error messages on the follower nodes:

dropped MsgProp to 247ae21ff9436b2d since streamMsg's sending buffer is full
dropped MsgAppResp to 247ae21ff9436b2d since streamMsg's sending buffer is full

These errors may be resolved by prioritizing etcd's peer traffic over its client traffic. On Linux, peer traffic can be prioritized by using the traffic control mechanism:

tc qdisc add dev eth0 root handle 1: prio bands 3
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip sport 2380 0xffff flowid 1:1
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip dport 2380 0xffff flowid 1:1
tc filter add dev eth0 parent 1: protocol ip prio 2 u32 match ip sport 2379 0xffff flowid 1:1
tc filter add dev eth0 parent 1: protocol ip prio 2 u32 match ip dport 2379 0xffff flowid 1:1


##############endpoint

[root@k2 ~]# export ETCDCTL_ENDPOINT=http://192.168.31.102:2379,http://192.168.31.103:2379,http://192.168.31.104:2379
 
ETCDCTL_API=3 etcdctl --endpoints $ENDPOINT snapshot save snapshot.db



#############################limite

Request size limit

etcd is designed to handle small key value pairs typical for metadata. Larger requests will work, but may increase the latency of other requests. For the time being, etcd guarantees to support RPC requests with up to 1MB of data. In the future, the size limit may be loosened or made configurable.
Storage size limit

The default storage size limit is 2GB, configurable with --quota-backend-bytes flag; supports up to 8GB.



Small cluster

A small cluster serves fewer than 100 clients, fewer than 200 of requests per second, and stores no more than 100MB of data.

Example application workload: A 50-node Kubernetes cluster
Provider    Type    vCPUs   Memory (GB)     Max concurrent IOPS     Disk bandwidth (MB/s)
AWS     m4.large    2   8   3600    56.25
GCE     n1-standard-1 + 50GB PD SSD     2   7.5     1500    25
Medium cluster

A medium cluster serves fewer than 500 clients, fewer than 1,000 of requests per second, and stores no more than 500MB of data.

Example application workload: A 250-node Kubernetes cluster
Provider    Type    vCPUs   Memory (GB)     Max concurrent IOPS     Disk bandwidth (MB/s)
AWS     m4.xlarge   4   16  6000    93.75
GCE     n1-standard-4 + 150GB PD SSD    4   15  4500    75
Large cluster

A large cluster serves fewer than 1,500 clients, fewer than 10,000 of requests per second, and stores no more than 1GB of data.

Example application workload: A 1,000-node Kubernetes cluster
Provider    Type    vCPUs   Memory (GB)     Max concurrent IOPS     Disk bandwidth (MB/s)
AWS     m4.2xlarge  8   32  8000    125
GCE     n1-standard-8 + 250GB PD SSD    8   30  7500    125
xLarge cluster

An xLarge cluster serves more than 1,500 clients, more than 10,000 of requests per second, and stores more than 1GB data.

Example application workload: A 3,000 node Kubernetes cluster
Provider    Type    vCPUs   Memory (GB)     Max concurrent IOPS     Disk bandwidth (MB/s)
AWS     m4.4xlarge  16  64  16,000  250
GCE     n1-standard-16 + 500GB PD SSD   16  60  15,000  250





################################## 加密连接
Securing etcd clusters

Access to etcd is equivalent to root permission in the cluster so ideally only the API server should have access to it. 
Considering the sensitivity of the data, it is recommended to grant permission to only those nodes that require access to 
etcd clusters.

To secure etcd, either set up firewall rules or use the security features provided by etcd. etcd security features depend 
on x509 Public Key Infrastructure (PKI). To begin, establish secure communication channels by generating a key and 
certificate pair. For example, use key pairs peer.key and peer.cert for securing communication between etcd members,
 and client.key and client.cert for securing communication between etcd and its clients. See the example scripts provided
  by the etcd project to generate key pairs and CA files for client authentication.
Securing communication

To configure etcd with secure peer communication, specify flags --peer-key-file=peer.key and --peer-cert-file=peer.cert, and use https as URL schema.

Similarly, to configure etcd with secure client communication, specify flags --key-file=k8sclient.key and --cert-file=k8sclient.cert, and use https as URL schema.



