#### VPC mirroring is a feature offered by AWS that copies network traffic from one Amazon EC2 instance and sends it to another EC2 instance. Resurface can make use of VPC mirroring to allow you to see API calls at a deeper level from a safe distance. This is a great option to increase API observability and to monitor API threats without modifying your application.

## Requirements:

- An AWS subscription
- At least two Amazon EC2 instances:
    - The two instances must use either the same VPC, or different VPCs connected via [VPC peering](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html).
    - It’s recommended to use nitro-based hypervisor EC2 instance types, since the VPC mirroring feature might not work on other types, like T2. [Learn more](https://docs.aws.amazon.com/vpc/latest/mirroring/traffic-mirroring-considerations.html).
    
## Set up VPC mirroring

For this guide we have set up two T3 type EC2 instances running Amazon Linux 2, one named *talker* and the other named *listener*:

![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632324946770_image.png)


*talker* will be the source machine whose network traffic is to be mirrored, while *listener* will be the target machine that will receive the mirrored traffic.


- **Step 1**: Create an inbound rule for the security group of your EC2 target machine. It should accept UPD traffic at port 4789 from the source machine.

 - First, copy the private IP address of the source machine
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325007248_image.png)
&nbsp;
  - Then, go to the security group of the target machine
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325102369_image.png)
&nbsp;
  - Click on *Edit inbound rules*
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325229852_image.png)
&nbsp;
  - Click *Add rule*, and a new row will appear. Choose **Custom UDP** for the *Type*, enter **4789** for the *Port range*, choose **Custom** for the *Source* and paste the source IP address we copied earlier in the search box. It will automatically append an extra `/32` to the end of it to make it a valid CIDR. Click *Save rules*.
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325362056_image.png)

&nbsp;
- **Step 2**: Create mirror target. This tells AWS which interface will receive the mirrored traffic.

    - Copy the listener’s network interface ID
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325522534_image.png)
&nbsp;
    - Click on the VPC ID for either machine (both should have the same VPC ID)
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325625559_image.png)
&nbsp;
    - Once in the VPC Management Console, find the *TRAFFIC MIRRORING* section at the end on the sidebar. Click on *Mirror Targets*
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325685648_image.png)
&nbsp;
    - Click on *Create traffic mirror target*
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632254906642_image.png)
&nbsp;
    - Paste the network interface ID we copied earlier in the *Target* search box under the *Choose target* section. Click *Create*.
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325767910_image.png)

&nbsp;
- **Step 3**: Create mirror filter. This tells AWS which traffic to mirror based on Protocol, Port range and IP address.

  - Go back to the VPC Management Console, find the *TRAFFIC MIRRORING* section and click on *Mirror Filters*
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632254780024_image.png)
&nbsp;
  - Click on *Create traffic mirror filter*
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632255593248_image.png)
&nbsp;
  - For the purposes of this guide, we are going to **accept** to mirror all **TCP** traffic going to and coming from anywhere (CIDR &nbsp;**`0.0.0.0/0`**), but feel free to add more rules to either accept or reject mirroring specific traffic. For example, a common rule would be to reject mirroring all SSH traffic on port 22. Click *Create*.
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632258291615_image.png)

&nbsp;
- **Step 4**: Create mirror session
    - Go back to the EC2 instances and copy the talker’s network interface ID
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632325961045_image.png)
&nbsp;
    - Go to the VPC Management Console, find the *TRAFFIC MIRRORING* section and click on *Mirror Sessions*
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632254798326_image.png)
&nbsp;
    - Click on *Create traffic mirror session*
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632258823442_image.png)
&nbsp;
    - Paste the network interface ID you copied earlier in the *Mirror source* search box under the *Session settings* section. Choose the mirror target you created back in step 2. Click *Create*.
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632326043811_image.png)
&nbsp;
    - Scroll down and select the filter you created back in step 3 for *Filter* under *Additional settings*. Also, type in **1** for the *Session number*. Click *Create*.
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632326164585_image.png)

&nbsp;
- **Step 5**: Create virtual VXLAN interface on target. All mirrored traffic is encapsulated in a VXLAN header. We can create a virtual network interface on top of an existing interface as a tunnel endpoint dedicated to this VPC mirroring session.
    - Go back to the *Mirror Sessions* section in the VPC Management Console, and click on the *Session ID* of the session we created in Step 4.
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632326280489_image.png)
&nbsp;
    - Copy the VXLAN Network Identifier (VNI). All VXLAN headers are associated with the 24-bit segment ID named VXLAN Network Identifier (VNI) for a given VPC mirroring session.
![](https://paper-attachments.dropbox.com/s_A0D03A04462930A019871D1BBC612B567991ECE6B0A63BBDB0EF948A9C60C658_1632326333668_image.png)
&nbsp;
    - SSH into the listener machine and execute the following command, substituting the highlighted parameters for your own

   <pre>
   sudo ip link add vx0 type vxlan id **8864121** local **172.31.15.169** remote **172.31.0.210** dev eth0 dstport 4789
   </pre>
Here we are adding a virtual link named `vx0` that will work as a VXLAN interface on top of the `eth0` device for all packets containing the VNI **`8864121`** in their VXLAN header. Be sure to substitute the VNI as well as the **`172.31.15.169`** and **`172.31.0.210`** addresses that correspond to the private IP addresses of the talker and listener machines, respectively.

   Then, just change the state of the device to UP:
    
          sudo ip link set vx0 up

&nbsp;
## Using Resurface to explore mirrored API calls

- First, build the network sniffer image

    - Clone our GitHub repo
    
          git clone https://github.com/resurfaceio/network-sniffer.git
          
    &nbsp;
    - `cd` into the directory where you cloned it

          cd network-sniffer
    &nbsp;
    - Build the image
          docker build -t goreplay-resurface -f Dockerfile.sidecar .


- Then, modify `src\.env` with the required [environment variables](https://github.com/resurfaceio/network-sniffer/blob/master/README.md#environment-variables) accordingly. In this case, we just want to set the environment variable VPC_MIRROR_DEVICE to the virtual link created in the previous step. So, our `.env` file looks like this:
<pre>
      APP_PORT=80
      <b><i>VPC_MIRROR_DEVICE="vx0"</i></b>
      USAGE_LOGGERS_URL=http://localhost:4001/message
      USAGE_LOGGERS_RULES="include debug\n"
</pre>

- Finally,
      docker-compose up


- Go to http://localhost:4002 and explore all the captured traffic!


#### Capturing traffic at the network level provides the most reliable source of information to reveal the actual requests your application is receiving, as well as the actual responses it sends back. There are no extra additions or modifications by proxies, gateways, or other intermediaries. In addition, since the network sniffer sits outside of your application’s critical path, there is no overhead increase at all!

