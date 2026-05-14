import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  await DCFlight.go(app: TestRoot());
}

class TestRoot extends DCFStatefulComponent {
  TestRoot({super.key});

  @override
  DCFComponentNode render() {
    final tab = useState<int>(1);

    return DCFView(
      layout: const DCFLayout(width: '100%', height: '100%', flexDirection: DCFFlexDirection.column),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.black),
      children: [
        DCFView(
          layout: const DCFLayout(width: '100%', height: 48, flexDirection: DCFFlexDirection.row),
          styleSheet: DCFStyleSheet(backgroundColor: DCFColors.gray900),
          children: [
            DCFButton(
              layout: const DCFLayout(flexGrow: 1, height: 48, justifyContent: DCFJustifyContent.center, alignItems: DCFAlign.center),
              styleSheet: DCFStyleSheet(backgroundColor: tab.state == 0 ? DCFColors.gray600 : DCFColors.gray900),
              onPress: (_) => tab.setState(0),
              children: [DCFText(content: '1. SCROLL TEST', textProps: DCFTextProps(fontSize: 11, fontWeight: DCFFontWeight.bold), styleSheet: DCFStyleSheet(primaryColor: DCFColors.white))],
            ),
            DCFButton(
              layout: const DCFLayout(flexGrow: 1, height: 48, justifyContent: DCFJustifyContent.center, alignItems: DCFAlign.center),
              styleSheet: DCFStyleSheet(backgroundColor: tab.state == 1 ? DCFColors.gray600 : DCFColors.gray900),
              onPress: (_) => tab.setState(1),
              children: [DCFText(content: '2. WEBGPU DRAG', textProps: DCFTextProps(fontSize: 11, fontWeight: DCFFontWeight.bold), styleSheet: DCFStyleSheet(primaryColor: DCFColors.white))],
            ),
          ],
        ),
        DCFView(
          layout: const DCFLayout(width: '100%', flexGrow: 1),
          children: [if (tab.state == 0) _ScrollTest() else _WebGPUDragTest()],
        ),
      ],
    );
  }
}

class _ScrollTest extends DCFStatelessComponent {
  _ScrollTest({super.key});

  @override
  DCFComponentNode render() => _buildInner();
  DCFComponentNode _buildInner() => DCFWebView(
    webViewProps: const DCFWebViewProps(source: _html, loadMode: DCFWebViewLoadMode.htmlString, scrollEnabled: true),
    layout: const DCFLayout(width: '100%', height: '100%'),
  );

  static const String _html = '''<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width,initial-scale=1"/>
<style>body{margin:0;font-family:sans-serif;background:#0a0a14;color:#eee;}.box{margin:10px 14px;padding:18px;border-radius:8px;font-size:17px;font-weight:bold;text-align:center;}</style>
</head><body>
<h2 style="text-align:center;padding:16px;color:#0af;margin:0">Scroll Test</h2>
<p style="text-align:center;color:#888;padding:0 16px 12px;margin:0">Scroll this list. Works = WebView touch is fine.</p>
<div class="box" style="background:#1a2a3a;color:#0af">Item 1</div>
<div class="box" style="background:#2a1a3a;color:#f0a">Item 2</div>
<div class="box" style="background:#1a3a2a;color:#0fa">Item 3</div>
<div class="box" style="background:#3a2a1a;color:#fa0">Item 4</div>
<div class="box" style="background:#1a2a3a;color:#0af">Item 5</div>
<div class="box" style="background:#2a1a3a;color:#f0a">Item 6</div>
<div class="box" style="background:#1a3a2a;color:#0fa">Item 7</div>
<div class="box" style="background:#3a2a1a;color:#fa0">Item 8</div>
<div class="box" style="background:#1a2a3a;color:#0af">Item 9</div>
<div class="box" style="background:#2a1a3a;color:#f0a">Item 10</div>
<div class="box" style="background:#1a3a2a;color:#0fa">Item 11</div>
<div class="box" style="background:#3a2a1a;color:#fa0">Item 12</div>
<div class="box" style="background:#1a2a3a;color:#0af">Item 13</div>
<div class="box" style="background:#2a1a3a;color:#f0a">Item 14</div>
<div class="box" style="background:#1a3a2a;color:#0fa">Item 15</div>
<div class="box" style="background:#3a2a1a;color:#fa0">Item 16</div>
<div class="box" style="background:#1a2a3a;color:#0af">Item 17</div>
<div class="box" style="background:#2a1a3a;color:#f0a">Item 18</div>
<div class="box" style="background:#1a3a2a;color:#0fa">Item 19</div>
<div class="box" style="background:#3a2a1a;color:#fa0">Item 20 - bottom</div>
</body></html>''';

}

class _WebGPUDragTest extends DCFStatelessComponent {
  _WebGPUDragTest({super.key});

  static const String _script = r'''
  (async () => {
    if (!navigator.gpu) { setStatus('NO WebGPU'); return; }
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) { setStatus('no adapter'); return; }
    const device = await adapter.requestDevice();
    const ctx    = canvas.getContext('webgpu');
    const fmt    = navigator.gpu.getPreferredCanvasFormat();
    const verts  = new Float32Array([0,0.65,1,.2,.2, -.65,-.45,.2,1,.2, .65,-.45,.2,.2,1]);
    const vBuf   = device.createBuffer({size:verts.byteLength,usage:GPUBufferUsage.VERTEX|GPUBufferUsage.COPY_DST});
    device.queue.writeBuffer(vBuf,0,verts);
    const uBuf   = device.createBuffer({size:4,usage:GPUBufferUsage.UNIFORM|GPUBufferUsage.COPY_DST});
    const sm = device.createShaderModule({code:`
@group(0) @binding(0) var<uniform> a:f32;
struct VI{@location(0)p:vec2f,@location(1)c:vec3f}
struct VO{@builtin(position)pos:vec4f,@location(0)c:vec3f}
@vertex fn vs(v:VI)->VO{let cs=cos(a);let sn=sin(a);return VO(vec4f(v.p.x*cs-v.p.y*sn,v.p.x*sn+v.p.y*cs,0,1),v.c);}
@fragment fn fs(f:VO)->@location(0) vec4f{return vec4f(f.c,1);}`});
    const bgl = device.createBindGroupLayout({entries:[{binding:0,visibility:GPUShaderStage.VERTEX,buffer:{type:'uniform'}}]});
    const pipeline = device.createRenderPipeline({
      layout:device.createPipelineLayout({bindGroupLayouts:[bgl]}),
      vertex:{module:sm,entryPoint:'vs',buffers:[{arrayStride:20,attributes:[{shaderLocation:0,offset:0,format:'float32x2'},{shaderLocation:1,offset:8,format:'float32x3'}]}]},
      fragment:{module:sm,entryPoint:'fs',targets:[{format:fmt}]},
      primitive:{topology:'triangle-list'},
    });
    const bg = device.createBindGroup({layout:bgl,entries:[{binding:0,resource:{buffer:uBuf}}]});
    let angle=0,dragging=false,lastX=0;
    setStatus('DRAG LEFT/RIGHT TO ROTATE TRIANGLE');
    canvas.addEventListener('pointerdown',e=>{dragging=true;lastX=e.clientX;canvas.setPointerCapture(e.pointerId);postToDcf({type:'down'});});
    canvas.addEventListener('pointermove',e=>{if(!dragging)return;angle+=(e.clientX-lastX)*0.025;lastX=e.clientX;postToDcf({type:'drag'});});
    canvas.addEventListener('pointerup',()=>{dragging=false;postToDcf({type:'up'});});
    canvas.addEventListener('pointercancel',()=>{dragging=false;});
    function frame(){
      const W=canvas.clientWidth||300,H=canvas.clientHeight||300;
      if(canvas.width!==W||canvas.height!==H){canvas.width=W;canvas.height=H;}
      ctx.configure({device,format:fmt,alphaMode:'opaque'});
      device.queue.writeBuffer(uBuf,0,new Float32Array([angle]));
      const enc=device.createCommandEncoder();
      const pass=enc.beginRenderPass({colorAttachments:[{view:ctx.getCurrentTexture().createView(),loadOp:'clear',storeOp:'store',clearValue:[0.04,0.04,0.1,1]}]});
      pass.setPipeline(pipeline);pass.setBindGroup(0,bg);pass.setVertexBuffer(0,vBuf);pass.draw(3);pass.end();
      device.queue.submit([enc.finish()]);
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  })();
  ''';

  @override
  DCFComponentNode render() {
    return DCFWebGPUView(
      gpuViewProps: const DCFWebGPUViewProps(script: _script),
      layout: const DCFLayout(width: '100%', height: '100%'),
    );
  }
}
