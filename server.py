from fastapi import FastAPI, Request, Body 
import os, subprocess, time,uvicorn
app = FastAPI()

cloud_provider="azure"
client_file="/home/ysj/coderepo/openvpn/client1.ovpn"

def tf_apply(tf_dir):
    pwd=os.getcwd()  
    subprocess.run(f"terraform -chdir={tf_dir} init",shell=True)
    subprocess.run(f"terraform -chdir={tf_dir} -auto-approve",shell=True)

def tf_destroy(tf_dir, tfvar_input_file):
    subprocess.run(f"terraform -chdir={tf_dir} destroy -auto-approve", shell=True)

@app.post("/create-openvpn-server")
async def create_openvpn_server(request: Request, body: Body[str]):
    # Create an OpenVPN server using Terraform
    tf_dir=os.getcwd()+"/terraform"+"/"+cloud_provider
    tf_apply(tf_dir=tf_dir)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)