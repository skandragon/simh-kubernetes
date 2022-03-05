# simh-kubernetes

A small Vax (in my case running OpenVMS) cluster in Kubernetes.

This requires some special permissions, so is unlikely to work
on an actual cloud provider.  I would very much like to implement
some sort of network proxy that removes the need for any priv'd
containers, and implement the ethernet layer in user space as
some sort of bridge.

# Architecture

I run 5 nodes, each with two disks.  Under VMS, these are named
DSA0: and DSA1:.  DSA0: is where I install VMS, by following this guide:
[Installing VMS in SIMH on Linux](https://vanalboom.org/node/18).
While this guide got me started, I am using a different version
of simh, so many of the commands will not be the same.  See
my example configuration files for working examples.

I also looked at
[Clustering OpenVMS on SIMH](https://vanalboom.org/node/19)
to set up clustering.  This walks through setting up two nodes
in a cluster and mentions expanding this to three, but isn't
clear on what you need to change.  See my notes below for what
I did.

In my case, I'm running OpenVMS 7.3, which is the latest I could
obtain for this cluster.  Install media is available on DSA3:, which
you will have to provide.

The cluster is implemented as a stateful set, because this allows
an ordered startup.  If you are clustering 5 nodes like I am, you
will need to make sure at least 3 are running (after clustering)
to maintain the quorum.

# My Environment

I have both Raspberry Pi 4s and x86 machines in my Kubernetes
cluster.  The image I build runs on either, although the Raspberry
Pi containers will run a little more slowly.  It will probably
still run much faster than the Vax hardware it emulates, however...

I use Longhorn for block storage to my Kubernetes nodes, and each
statefulset gets its own volume where its disks and any install
media reside.  Once DecNET is enabled, you could remove all but
one of the install media copies, or keep them around.  Disk space
is cheap.

All my Kubernetes nodes have a dedicated VLAN (vlan17) for this VMS
cluster, and that is the interface simh is configured to use.  While
I do have DHCP on this interface, I opted to use manual IP addresses
when installing TCP on each VMS node, as the strange Ethernet MAC
swap DecNET does tended to cause some instability as I could get
multiple IP addresses or sometimes just one, and sometimes they would
come and go.

# About the container image

It's in `docker-images`.

It requires some capabilities you likely won't have in any
cloud Kubernetes provider, unless you have a lot of control over
its setup.  These are listed in the manifest.

The image will check out the main branch from the simh repo, (4.0.0 pre-release of some sort I think) and build it in an Alpine linux environment.  It will then start fresh in a new Alpine image, copy over the few binaries I build, and install some supporting libraries needed.

**NO OPERATING SYSTEM IMAGES FROM VMS OR ANY OTHER COMMERCIALLY
LICENSED OPERATING SYSTEM IS INCLUDED.**
If you want to run VMS, you'll have to get it yourself.

The image includes a run.sh that is pretty simple; it checks to see
if there is a hostname in `/disks/simh/hostname`, and if so, it will
look into the configmap to see if this node should start up
at container start.  If the hostname file is not present, or that
hostname is not listed in the configmap as 'autostart', the container
will run `sleep infinity` to allow you to shell in and set things up.

`/disks` is the volume mounted to store the VAX's disks.

`/disks/simh/vax8600.ini` holds the startup config for this node.
Very little is changed between the various nodes other than the
MAC address.  I made mine up, using what I think is a DEC prefix,
because it's very unlikely I'll end up with a conflict there.

If the container exits for some reason, like when the VMS
`shutdown` is run, it will `sleep infinity` as well.  If
the node is rebooted, the simulator will not exit, so the
VAX will come up again.

# Starting the first node

Adjust the PVC in the manifest to come from some sort of block
storage you have available.  I have used Longhorn and iSCSI, but
settled on Longhorn as it is sufficiently fast.

Set the stateful set to only have one replica, and apply the manifest.

After the first node enters its sleep loop, shell into the
pod.  Under `/disks` you will want to copy in an OS image,
which in my case is named `/disks/OpenVMS-VAX-073-OS.iso`.

Copy in a simh configuration to `/disks/simh/vax8600.ini`, and 
make sure the RQ3 attachment in that file matches your OS
image.  If you are using my sample config files, make sure you
comment out the 'boot rq0' line for now.

I have only tried the VAX 8600 (well, 8650) emulation, but others
should work as well.  I have tried no other OS than VMS 7.3.

Start the simulator manually, this time:

```
cd /disks/simh
/simh/BIN/vax8600
```

Once the simulator starts, boot into the install media with `boot rq3`.

After the OS is installed, it will ask you to halt the CPU.  Do this
by pressing `^E` (control-E).  At the simh prompt, type 'quit'
to exit.  I tried not explicitly exiting, and found it might not
properly flush out the emulated disks.

Now, go into the simh config `vax8600.ini` and add or uncomment the
`boot rq0` line at the end.

This would be a good time to add the node name to `/disks/simh/hostname` and to the configmap in the manifest.  The hostname
in the file and configmap are just used to decide to auto-boot
the simulator on container startup.

At this point, you can either start the node again, or once set
to auto-start, just restart the pod.

## Node naming

While I named my VAXen "VAX0" through "VAX4" I wish I had named
them "VAX1" through "VAX5", since many things like the DECnet
addresses and the allocation numbers for remote disks cannot
use 0, so are off by one.

## Networking

This first node is assigned DECnet address 1.1 in my case,
and therefore SCSSYSTEMID of 1025 (1024 * 1 + 1).  The next node,
1.2, will be 1026 (1024 * 1 + 2) and so on.

When setting up IP networking, I manually assign an IP address.
I also make sure telnet is running, and configure the DNS (BIND)
lookup to use my home DNS server, and default static route.

# Starting the other nodes

Increase the replica count by one, and do all the above steps.
Repeat as many times as you like until you get however many
simulated VAX nodes you want.

Once all the nodes you want to fire up are running, cluster if
you wish.  I did, although with 5 nodes I found I could only actually
put 3 disks in a shadow disk set under VMS 7.3, so if you choose
more than three nodes in your cluster, you will need to change the
above mentioned guide a bit.

With my 5 nodes, I set `EXPECTED_VOTES` to 5, and each node has `VOTES` set to 1.  This means if I shut the whole cluster down, I will need to bring three nodes up before any of them will continue
booting past the "joining or creating" phase of DECnet startup.

# Upgrading

Well, that's pretty unlikely, eh?  I mean, this is an unsupported
CPU on an unsupported OS using a simulator rather than actual
hardware.

I may release newer versions of the docker image, including one that
uses some other method to decide to auto-boot than a configmap.