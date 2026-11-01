import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = resolve(process.argv[2]);
const outDir = resolve(process.argv[3]);
mkdirSync(outDir, { recursive: true });

const THREE = await import(pathToFileURL(join(root, 'build', 'three.module.js')).href);

class WebGL2RenderingContext {}
globalThis.WebGL2RenderingContext = WebGL2RenderingContext;

const constants = new Map();
let nextConstant = 0x10000;
const captured = [];
const programs = new Map();
let nextId = 1;

function constant(name) {
  if (!constants.has(name)) constants.set(name, nextConstant++);
  return constants.get(name);
}

const methods = {
  createShader: () => ({ id: nextId++ }),
  createProgram: () => ({ id: nextId++ }),
  createBuffer: () => ({ id: nextId++ }),
  createTexture: () => ({ id: nextId++ }),
  createFramebuffer: () => ({ id: nextId++ }),
  createRenderbuffer: () => ({ id: nextId++ }),
  createVertexArray: () => ({ id: nextId++ }),
  shaderSource: (shader, source) => captured.push({ shader, source }),
  getShaderParameter: () => true,
  getProgramParameter: (program, pname) => (pname === constant('LINK_STATUS') ? true : 0),
  getShaderInfoLog: () => '',
  getProgramInfoLog: () => '',
  getExtension: () => null,
  getSupportedExtensions: () => [],
  getParameter: (pname) => {
    if (pname === constant('VERSION')) return 'WebGL 2.0 (mock)';
    if (pname === constant('SHADING_LANGUAGE_VERSION')) return 'WebGL GLSL ES 3.00 (mock)';
    if (pname === constant('VENDOR')) return 'mock';
    if (pname === constant('RENDERER')) return 'mock';
    return 0;
  },
  getContextAttributes: () => ({ alpha: true, antialias: false, depth: true, stencil: false }),
  getShaderPrecisionFormat: () => ({ precision: 23, rangeMin: 127, rangeMax: 127 }),
  getUniformLocation: () => ({ id: nextId++ }),
  getAttribLocation: () => 0,
  getError: () => 0,
  checkFramebufferStatus: () => constant('FRAMEBUFFER_COMPLETE'),
  isContextLost: () => false,
};

const gl = new Proxy({}, {
  get(target, prop) {
    if (prop === 'constructor') return WebGL2RenderingContext;
    if (typeof prop !== 'string') return undefined;
    if (prop in methods) return methods[prop];
    if (/^[A-Z][A-Z0-9_]*$/.test(prop)) return constant(prop);
    return () => 0;
  },
  getPrototypeOf() {
    return WebGL2RenderingContext.prototype;
  },
});

const canvas = {
  width: 256,
  height: 256,
  clientWidth: 256,
  clientHeight: 256,
  style: {},
  addEventListener() {},
  removeEventListener() {},
  getContext: () => gl,
};

const renderer = new THREE.WebGLRenderer({ canvas, context: gl, antialias: false });
renderer.setSize(256, 256);

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, 1, 0.1, 100);
camera.position.z = 3;
const geometry = new THREE.BoxGeometry(1, 1, 1);

scene.add(new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ color: 0x336699 })));

scene.add(new THREE.DirectionalLight(0xffffff, 1));
scene.add(new THREE.Mesh(geometry, new THREE.MeshStandardMaterial({ color: 0x993366, roughness: 0.5 })));

const instanced = new THREE.InstancedMesh(geometry, new THREE.ShaderMaterial({
  vertexShader: `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * instanceMatrix * vec4(position, 1.0);
    }`,
  fragmentShader: `
    varying vec2 vUv;
    uniform vec3 tint;
    void main() {
      gl_FragColor = vec4(tint * vUv.x, 1.0);
    }`,
  uniforms: { tint: { value: new THREE.Vector3(1, 0.5, 0.25) } },
}), 2);
scene.add(instanced);

renderer.render(scene, camera);

const pairs = [];
let index = 0;
for (let i = 0; i < captured.length; i += 1) {
  const entry = captured[i];
  const isVertex = entry.source.includes('gl_Position');
  const isFragment = entry.source.includes('gl_FragColor') || entry.source.includes('pc_fragColor');
  if (!isVertex && !isFragment) continue;
  pairs.push(entry);
}

const names = ['meshbasic', 'meshstandard', 'instanced-shadermaterial'];
const programsSeen = [];
for (let i = 0; i < pairs.length; i += 2) {
  const vert = pairs[i];
  const frag = pairs[i + 1];
  const name = names[index++] ?? `program-${index}`;
  writeFileSync(join(outDir, `${name}.vert`), vert.source);
  writeFileSync(join(outDir, `${name}.frag`), frag ? frag.source : '');
  programsSeen.push({ name, vertexBytes: vert.source.length, fragmentBytes: frag ? frag.source.length : 0 });
}
console.log(JSON.stringify({ three: THREE.REVISION, captured: captured.length, programs: programsSeen }, null, 2));
