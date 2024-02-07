from diagrams import Cluster, Diagram
from diagrams.onprem.compute import Server


from diagrams.azure.compute import VMLinux
from diagrams.azure.database import DatabaseForPostgresqlServers
from diagrams.azure.storage import BlobStorage



# Variables
title = "VPC with 1 public subnet for the client and TFE server"
outformat = "png"
filename = "diagram_tfe_fdo_azure_mounted_disk"
direction = "TB"


with Diagram(
    name=title,
    direction=direction,
    filename=filename,
    outformat=outformat,
) as diag:
    # Non Clustered
    user = Server("user")

    # Cluster 
    with Cluster("Azure"):
        with Cluster("vpc"):
    
            with Cluster("Availability Zone: \n\n  "):
                # Subcluster 
                with Cluster("subnet_public1"):
                    ec2_client_machine = VMLinux("Client_machine")
                    ec2_tfe_server = VMLinux("TFE_server")
               
    # Diagram

    user >> [ec2_tfe_server,
             ec2_client_machine]
   
diag
