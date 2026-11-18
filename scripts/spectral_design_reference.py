"""Independent NumPy design references, NOT Metal validation or app screenshots.
Run: python scripts/spectral_design_reference.py --out build_out/spectral46
Checks real-input Fourier symmetry, quadrature, normalized convolution and finite defaults.
"""
from pathlib import Path
import argparse, json
import numpy as np
from PIL import Image, ImageDraw

def smooth(a,b,x):
    v=np.clip((x-a)/(b-a),0,1);return v*v*(3-2*v)

def render(clock=0):
    n=128;y,x=np.mgrid[:n,:n];u=(x+.5)/n;v=(y+.5)/n
    source=np.stack([.5+.2*np.sin(u*57+np.sin(v*19))+.15*np.cos(v*83)+.1*np.sin((u+v)*131),.5+.3*np.sin(u*17+v*11),.5+.3*np.cos(v*23-u*9)],-1)
    source[((x//13+y//17)%3)==0]*=.3
    f=np.fft.fft2(source,axes=(0,1));mean=source.mean((0,1))
    ky,kx=np.meshgrid(np.fft.fftfreq(n),np.fft.fftfreq(n),indexing='ij');r=np.hypot(kx,ky);direction=kx*np.cos(np.deg2rad(25))+ky*np.sin(np.deg2rad(25))
    nyquist=(x==n//2)|(y==n//2);dc=(x==0)&(y==0)
    def inverse(z):
        value=np.fft.ifft2(z,axes=(0,1));assert np.max(np.abs(value.imag))<1e-8
        return np.maximum(0,value.real)
    def filtered(g):
        g=np.array(g,copy=True);g[dc]=1
        return inverse(f*g[...,None])
    out={}
    out['Source']=source
    out['Spectral Band Filter']=filtered(smooth(-.005,.055,r)*(1-smooth(.22,.28,r)))
    delta=np.abs(np.arctan2(np.sin(np.arctan2(ky,kx)-np.deg2rad(25)),np.cos(np.arctan2(ky,kx)-np.deg2rad(25))));delta=np.minimum(delta,np.pi-delta)
    gate=1-.8*(1-smooth(np.deg2rad(20),np.deg2rad(30),delta));gate[nyquist]=1
    out['Directional Spectrum Gate']=filtered(gate)
    d=np.minimum(np.hypot(kx-.05,ky),np.hypot(kx+.05,ky));g=1-.9*np.exp(-.5*d*d/.045**2);g[nyquist]=1
    out['Paired Notch Reject']=filtered(g)
    mag=np.abs(f);g=(.02/(np.maximum(1e-6,mag/(n*n)+.02)))**.7;g[dc]=1
    out['Spectral Whiten']=inverse(f*g)
    negative=(kx<0)|((kx==0)&(ky<0));cx=np.where(negative,-kx,kx);cy=np.where(negative,-ky,ky)
    random=np.mod(np.sin(cx*n*127.1+cy*n*311.7+3)*43758.5453,1)
    phase=((random*2-1)*np.pi*.8+clock*.8)*np.where(negative,-1,1);phase[nyquist|dc]=0
    z=f*np.exp(1j*phase[...,None]);out['Phase Scramble']=inverse(z)
    phase=np.sign(direction)*np.pi/2;phase[nyquist|dc]=0
    out['Quadrature Image']=inverse(f*np.exp(1j*phase[...,None]))
    cycle=np.mod(r/.08-.2,1);out['Frequency Comb']=filtered(.1+.9*(1-smooth(.17,.23,np.minimum(cycle,1-cycle))))
    logf=np.fft.fft2(np.log(np.maximum(.0001,source)),axes=(0,1));g=.85+(1.2-.85)*(1-np.exp(-r*r/(2*.04**2)))
    out['Homomorphic Contrast']=np.exp(np.fft.ifft2(logf*g[...,None],axes=(0,1)).real)
    out['Image Spectrum']=np.fft.fftshift(np.log(1+32*mag*64/(n*n))/np.log(33),axes=(0,1))
    cep=np.fft.ifft2(np.log(1+mag/(.01*n*n)),axes=(0,1)).real
    out['Image Cepstrum']=np.abs(np.fft.fftshift(cep,axes=(0,1)))*100
    h=np.exp(-2*np.pi**2*1.5**2*r*r);out['Regularized Deblur']=filtered(np.minimum(3,1.05*h/(h*h+.05)))
    # Linear convolution oracle: a padded centered PSF, normalized to unit energy.
    psf=np.exp(-.5*(((x-n/2)/5)**2+((y-n/2)/2)**2));psf/=psf.sum()
    pad=np.zeros((2*n,2*n,3));pad[n//2:n//2+n,n//2:n//2+n]=source
    kernel=np.zeros((2*n,2*n));kernel[n//2:n//2+n,n//2:n//2+n]=psf
    convolution=np.fft.ifft2(np.fft.fft2(pad,axes=(0,1))*np.fft.fft2(np.fft.ifftshift(kernel))[...,None],axes=(0,1)).real
    assert abs(convolution.sum()-source.sum())<1e-7
    out['Image Convolution']=convolution[n//2:n//2+n,n//2:n//2+n]
    ref=np.roll(source,(5,-9),(0,1));rf=np.fft.fft2(ref,axes=(0,1));cross=f*np.conj(rf);scale=np.maximum(np.abs(cross),1e-6)**.8
    corr=cross/scale*np.exp(-2*np.pi**2*2**2*r*r)[...,None];corr[0,0]=0
    out['Image Correlation']=np.abs(np.fft.fftshift(np.fft.ifft2(corr,axes=(0,1)).real,axes=(0,1)))*10
    ref2=np.stack([u,v,.5+.45*np.sin(x*.12)*np.cos(y*.1)],-1);rf=np.fft.fft2(ref2,axes=(0,1));target=.3*mag+.7*np.abs(rf)*mean/np.maximum(ref2.mean((0,1)),1e-6)
    z=target*np.where(mag>1e-6,f/np.maximum(mag,1e-6),1);out['Magnitude Transfer']=inverse(z)
    phase=8*(direction*4)**3;phase[nyquist|dc]=0;out['Wave Dispersion']=inverse(f*np.exp(1j*phase[...,None]))
    # Independent single-frequency Hilbert oracle fixes phase sign and DC behavior.
    signal=.5+.2*np.cos(2*np.pi*np.arange(n)/n);zf=np.fft.fft(signal);ph=np.sign(np.fft.fftfreq(n))*np.pi/2;ph[n//2]=0
    assert np.max(np.abs(np.fft.ifft(zf*np.exp(1j*ph)).real-(.5-.2*np.sin(2*np.pi*np.arange(n)/n))))<1e-12
    for name,image in out.items(): assert np.isfinite(image).all(),name
    return out

def sheet(out):
    canvas=Image.new('RGB',(4*256,4*221),(18,18,25));draw=ImageDraw.Draw(canvas)
    for i,(name,array) in enumerate(out.items()):
        image=Image.fromarray(np.uint8(np.clip(array,0,1)*255)).resize((246,186))
        x=(i%4)*256;y=(i//4)*221;canvas.paste(image,(x+5,y+27));draw.text((x+5,y+7),name,fill='white')
    return canvas
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--out',default='build_out/spectral46');args=parser.parse_args();folder=Path(args.out);folder.mkdir(parents=True,exist_ok=True)
    out=render();sheet(out).save(folder/'design-reference.png')
    frames=[sheet(render(t)) for t in np.linspace(0,2,9)]
    frames[0].save(folder/'design-motion.gif',save_all=True,append_images=frames[1:],duration=120,loop=0)
    stats={key:float(np.mean(np.abs(image-out['Source']))) for key,image in out.items()}
    (folder/'oracle.json').write_text(json.dumps({'scope':'Independent CPU mathematics, not GPU verification','mean_absolute_change':stats,'oracles':'finite defaults, real inverse, convolution energy, Hilbert phase sign passed'},indent=2))
    print(json.dumps(stats,indent=2))
