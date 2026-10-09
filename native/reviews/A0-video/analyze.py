import subprocess,sys
v=sys.argv[1]; W,H=60,130; N=W*H
raw=subprocess.run(["ffmpeg","-v","error","-i",v,"-vf",f"fps=30,scale={W}:{H},format=gray","-f","rawvideo","-"],capture_output=True).stdout
n=len(raw)//N
d=[sum(abs(a-b) for a,b in zip(raw[i*N:(i+1)*N],raw[(i-1)*N:i*N]))/N/255*100 for i in range(1,n)]
runs=[];s=None
for i,x in enumerate(d):
    if x>0.3 and s is None:s=i
    if x<=0.3 and s is not None: runs.append((s,i-1));s=None
if s is not None: runs.append((s,len(d)-1))
print("frames",n)
for a,b in runs: print(f"{a/30:.2f}s-{(b+1)/30:.2f}s len={b-a+1} frames peak={max(d[a:b+1]):.1f}%")
