import 'dart:convert';

String buildWarehouse3dHtml({
  required String scriptBase,
  required Map<String, dynamic> blueprint,
  required List<Map<String, dynamic>> items,
  required int floor,
  String? warehouseName,
}) {
  final bpJson = jsonEncode(blueprint);
  final itemsJson = jsonEncode(items);
  final nameJson = jsonEncode(warehouseName ?? '');

  return '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>RAVEN ASTHA - Visualizador 3D</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      width: 100%; height: 100%;
      overflow: hidden;
      background-color: #f5f7f9;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Inter", sans-serif;
      user-select: none;
      -webkit-user-select: none;
    }
    #viewer-container {
      width: 100%; height: 100%;
      position: absolute; top: 0; left: 0;
      overflow: hidden;
    }
    #viewer-container canvas {
      display: block; width: 100% !important; height: 100% !important;
      outline: none;
    }
    .hud-controls {
      position: absolute; bottom: 16px; right: 16px;
      display: flex; flex-direction: column; gap: 8px;
      z-index: 20;
    }
    .hud-btn {
      width: 38px; height: 38px;
      border-radius: 10px;
      border: 1px solid rgba(226, 232, 240, 0.8);
      background: rgba(255, 255, 255, 0.92);
      backdrop-filter: blur(8px);
      box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08);
      color: #334155;
      font-size: 16px; font-weight: 700;
      display: flex; align-items: center; justify-content: center;
      cursor: pointer; transition: all 0.15s ease;
    }
    .hud-btn:active {
      transform: scale(0.92);
      background: #e2e8f0;
    }
    .hud-btn svg { width: 18px; height: 18px; stroke: currentColor; fill: none; stroke-width: 2; }
    .hud-info {
      position: absolute; top: 14px; left: 16px;
      background: rgba(255, 255, 255, 0.9);
      backdrop-filter: blur(8px);
      border: 1px solid rgba(226, 232, 240, 0.8);
      border-radius: 12px;
      padding: 8px 14px;
      box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06);
      font-size: 13px; font-weight: 600; color: #1e293b;
      display: flex; align-items: center; gap: 8px;
      z-index: 20;
      pointer-events: none;
    }
    .hud-badge {
      display: inline-block; width: 8px; height: 8px;
      border-radius: 50%; background: #10b981;
    }
    .loading-overlay {
      position: absolute; inset: 0;
      background: #f5f7f9;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      gap: 14px; z-index: 30;
      transition: opacity 0.3s ease;
    }
    .spinner {
      width: 36px; height: 36px;
      border: 3px solid #e2e8f0;
      border-top-color: #10b981;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .loading-text { font-size: 13px; font-weight: 500; color: #64748b; }
    .shelf-toast {
      position: absolute; bottom: 20px; left: 50%;
      transform: translateX(-50%) translateY(100px);
      background: #0f172a; color: #ffffff;
      padding: 10px 18px; border-radius: 20px;
      font-size: 13px; font-weight: 600;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
      transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      z-index: 25; pointer-events: none;
    }
    .shelf-toast.show { transform: translateX(-50%) translateY(0); }
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script>
    if (typeof THREE === 'undefined') {
      var s = document.createElement('script');
      s.src = 'https://unpkg.com/three@0.128.0/build/three.min.js';
      document.head.appendChild(s);
    }
  </script>
  <script>
$_orbitControlsJs
  </script>
  <script>
$_mapModelJs
  </script>
  <script>
$_objectLibraryJs
  </script>
</head>
<body>
  <div id="viewer-container"></div>

  <div id="loading" class="loading-overlay">
    <div class="spinner"></div>
    <div class="loading-text" id="loading-msg">Carregando armazém 3D...</div>
  </div>

  <div class="hud-info" id="hud-info" style="display:none;">
    <span class="hud-badge"></span>
    <span id="hud-name">Armazém</span>
  </div>

  <div class="hud-controls">
    <button class="hud-btn" id="btn-zoom-in" title="Aproximar">+</button>
    <button class="hud-btn" id="btn-zoom-out" title="Afastar">-</button>
    <button class="hud-btn" id="btn-reset" title="Restaurar visão">
      <svg viewBox="0 0 24 24"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>
    </button>
  </div>

  <div class="shelf-toast" id="shelf-toast">Prateleira selecionada</div>

  <script>
    (function() {
      const container = document.getElementById('viewer-container');
      const loadingEl = document.getElementById('loading');
      const loadingMsg = document.getElementById('loading-msg');
      const hudInfo = document.getElementById('hud-info');
      const hudName = document.getElementById('hud-name');
      const shelfToast = document.getElementById('shelf-toast');

      const injectedBlueprint = $bpJson;
      const injectedItems = $itemsJson;
      const injectedFloor = $floor;
      const injectedName = $nameJson;

      let scene, camera, renderer, controls;
      let floorMesh;
      let currentBlueprint = null;
      let currentItems = [];
      let currentFloor = injectedFloor;
      let shelfMeshes = [];
      let raycaster = new THREE.Raycaster();
      let mouse = new THREE.Vector2();
      let pointerDownPos = { x: 0, y: 0 };
      let defaultCamPos = { x: 20, y: 25, z: 30 };
      let defaultTarget = { x: 0, y: 0, z: 0 };

      function hexToInt(hex) {
        if (!hex || typeof hex !== 'string') return 0x3b82f6;
        const clean = hex.replace('#', '');
        return parseInt(clean, 16) || 0x3b82f6;
      }

      function initThree() {
        const w = container.clientWidth || window.innerWidth || 800;
        const h = container.clientHeight || window.innerHeight || 600;

        scene = new THREE.Scene();
        scene.background = new THREE.Color(0xf5f7f9);

        camera = new THREE.PerspectiveCamera(46, (w / (h || 1)) || 1.33, 0.1, 5000);
        camera.position.set(defaultCamPos.x, defaultCamPos.y, defaultCamPos.z);

        renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
        renderer.setSize(w, h);
        renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
        renderer.shadowMap.enabled = true;
        renderer.shadowMap.type = THREE.PCFSoftShadowMap;
        try { renderer.outputEncoding = THREE.sRGBEncoding; } catch(e) {}
        container.appendChild(renderer.domElement);

        if (typeof THREE.OrbitControls !== 'undefined') {
          controls = new THREE.OrbitControls(camera, renderer.domElement);
          controls.enableDamping = true;
          controls.dampingFactor = 0.08;
          controls.maxPolarAngle = Math.PI / 2 - 0.02;
          controls.minDistance = 2;
          controls.maxDistance = 500;
          controls.target.set(0, 0, 0);
          controls.update();
        }

        scene.add(new THREE.AmbientLight(0xffffff, 0.48));

        const sun = new THREE.DirectionalLight(0xffffff, 0.52);
        sun.position.set(30, 50, 30);
        sun.castShadow = true;
        sun.shadow.mapSize.width = 2048;
        sun.shadow.mapSize.height = 2048;
        sun.shadow.camera.near = 0.5;
        sun.shadow.camera.far = 300;
        const d = 40;
        sun.shadow.camera.left = -d;
        sun.shadow.camera.right = d;
        sun.shadow.camera.top = d;
        sun.shadow.camera.bottom = -d;
        scene.add(sun);

        const fill = new THREE.DirectionalLight(0xffffff, 0.18);
        fill.position.set(-30, 25, -30);
        scene.add(fill);

        floorMesh = new THREE.Mesh(
          new THREE.PlaneGeometry(2000, 2000),
          new THREE.MeshStandardMaterial({ color: 0xf2f4f6, roughness: 1 })
        );
        floorMesh.rotation.x = -Math.PI / 2;
        floorMesh.position.y = -0.01;
        floorMesh.receiveShadow = true;
        scene.add(floorMesh);

        window.addEventListener('resize', onResize);
        if (typeof ResizeObserver !== 'undefined') {
          const ro = new ResizeObserver(() => onResize());
          ro.observe(container);
          if (document.body) ro.observe(document.body);
        }

        renderer.domElement.addEventListener('pointerdown', onPointerDown);
        renderer.domElement.addEventListener('pointerup', onPointerUp);

        document.getElementById('btn-zoom-in').addEventListener('click', () => zoomCamera(0.8));
        document.getElementById('btn-zoom-out').addEventListener('click', () => zoomCamera(1.25));
        document.getElementById('btn-reset').addEventListener('click', resetCamera);

        animate();
      }

      function onResize() {
        if (!container || !camera || !renderer) return;
        const w = container.clientWidth || window.innerWidth;
        const h = container.clientHeight || window.innerHeight;
        if (w <= 0 || h <= 0) return;
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
        renderer.setSize(w, h);
      }

      function zoomCamera(factor) {
        if (!camera) return;
        if (controls) {
          const offset = camera.position.clone().sub(controls.target);
          offset.multiplyScalar(factor);
          camera.position.copy(controls.target).add(offset);
          controls.update();
        }
      }

      function resetCamera() {
        if (!camera) return;
        camera.position.set(defaultCamPos.x, defaultCamPos.y, defaultCamPos.z);
        if (controls) {
          controls.target.set(defaultTarget.x, defaultTarget.y, defaultTarget.z);
          controls.update();
        }
      }

      function onPointerDown(e) {
        pointerDownPos = { x: e.clientX, y: e.clientY };
      }

      function onPointerUp(e) {
        const dx = Math.abs(e.clientX - pointerDownPos.x);
        const dy = Math.abs(e.clientY - pointerDownPos.y);
        if (dx > 5 || dy > 5) return;

        const rect = renderer.domElement.getBoundingClientRect();
        mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
        mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
        raycaster.setFromCamera(mouse, camera);

        const hits = raycaster.intersectObjects(shelfMeshes, true);
        if (hits.length > 0) {
          let root = hits[0].object;
          while (root && !root.userData?.shelfId && root.parent) {
            root = root.parent;
          }
          if (root && root.userData?.shelfId) {
            selectShelf(root.userData.shelfId);
          }
        }
      }

      function selectShelf(shelfId) {
        const count = currentItems.filter(i => (i.location || '').startsWith(shelfId)).length;
        shelfToast.textContent = 'Prateleira ' + shelfId + ' · ' + count + ' item' + (count === 1 ? '' : 's');
        shelfToast.classList.add('show');
        setTimeout(() => shelfToast.classList.remove('show'), 2200);

        try {
          if (window.FlutterBridge && window.FlutterBridge.postMessage) {
            window.FlutterBridge.postMessage(shelfId);
          }
        } catch(e) {}

        try {
          window.parent.postMessage({
            type: 'SHELF_SELECTED',
            shelfId: shelfId,
            itemCount: count
          }, '*');
        } catch(e) {}
      }

      function clearSceneEntities() {
        const toRemove = [];
        scene.children.forEach(c => {
          if (c !== floorMesh && !(c instanceof THREE.Light)) {
            toRemove.push(c);
          }
        });
        toRemove.forEach(c => scene.remove(c));
        shelfMeshes = [];
      }

      function buildScene(blueprint, items) {
        clearSceneEntities();
        currentBlueprint = blueprint;
        currentItems = items || [];

        const scale = 0.06;
        const plan = window.ASTHAMapModel
          ? window.ASTHAMapModel.createScenePlan(blueprint || {}, { scale: scale, floorHeight: 160 })
          : { entities: [] };

        const cadBlueprint = plan.blueprint || blueprint;
        const cadShelves = (cadBlueprint && cadBlueprint.floors)
          ? Object.keys(cadBlueprint.floors).flatMap(level => {
              return (cadBlueprint.floors[level].shelves || [])
                .filter(s => s.visible !== false)
                .map(s => Object.assign({ _floorLevel: Number(level) || 0 }, s));
            })
          : [];

        const nonShelfEntities = (plan.entities || []).filter(e => e.type !== 'shelf');

        let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity, maxH = 3;

        const postMat = new THREE.MeshStandardMaterial({ color: 0x163e79, metalness: 0.15, roughness: 0.7 });
        const beamMat = new THREE.MeshStandardMaterial({ color: 0xb45309, metalness: 0.1, roughness: 0.7 });
        const boardMat = new THREE.MeshStandardMaterial({ color: 0x64748b, roughness: 0.9 });
        const archMat = new THREE.MeshStandardMaterial({ color: 0x78879a, roughness: 1 });
        const glassMat = new THREE.MeshStandardMaterial({ color: 0x38bdf8, roughness: 0.35, transparent: true, opacity: 0.65 });
        const dockMat = new THREE.MeshStandardMaterial({ color: 0x0ea5e9, roughness: 0.7 });

        const geomCache = new Map();
        function getBox(w, h, d) {
          const key = [w, h, d].map(n => Number(n).toFixed(3)).join(':');
          if (!geomCache.has(key)) geomCache.set(key, new THREE.BoxGeometry(w, h, d));
          return geomCache.get(key);
        }

        nonShelfEntities.forEach(entity => {
          try {
            let mesh;
            const w = Math.max(entity.width || 0.3, 0.08);
            const d = Math.max(entity.depth || 0.3, 0.08);
            const h = Math.max(entity.height || 3, 0.08);
            let y = entity.position.y;

            if (entity.type === 'wall') {
              const length = Math.max(entity.length || 0.1, 0.1);
              const depth = (entity.source.wallThickness || 10) * scale;
              const height = entity.height;
              y += height / 2;
              mesh = new THREE.Mesh(getBox(length, height, depth), archMat);
              mesh.rotation.y = -entity.lineAngle;
              mesh.castShadow = true;
              mesh.receiveShadow = true;
            } else if (entity.type === 'door') {
              y += h / 2;
              mesh = new THREE.Mesh(getBox(w, h, d), new THREE.MeshStandardMaterial({ color: 0x8b5a2b }));
            } else if (entity.type === 'window') {
              y += 40 * scale + h / 2;
              mesh = new THREE.Mesh(getBox(w, h, d), glassMat);
            } else if (entity.type === 'pillar') {
              y += h / 2;
              mesh = new THREE.Mesh(getBox(w, h, d), archMat);
              mesh.castShadow = true;
              mesh.receiveShadow = true;
            } else if (entity.type === 'zone') {
              const zw = Math.max(Math.abs(entity.source.x2 - entity.source.x1) * scale, 0.1);
              const zd = Math.max(Math.abs(entity.source.y2 - entity.source.y1) * scale, 0.1);
              mesh = new THREE.Mesh(
                new THREE.PlaneGeometry(zw, zd),
                new THREE.MeshBasicMaterial({ color: entity.color || 0xf97316, transparent: true, opacity: 0.28, depthWrite: false })
              );
              mesh.rotation.x = -Math.PI / 2;
              y += 0.02;
            } else if (entity.type === 'path') {
              const length = Math.max(entity.length || 1, 0.1);
              mesh = new THREE.Mesh(
                new THREE.PlaneGeometry(length, 0.5),
                new THREE.MeshBasicMaterial({ color: 0xeab308, depthWrite: false })
              );
              mesh.rotation.x = -Math.PI / 2;
              mesh.rotation.z = -entity.lineAngle;
              y += 0.04;
            } else if (entity.type === 'stairs') {
              const length = Math.max(entity.length || 1, 0.1);
              mesh = new THREE.Mesh(getBox(length, 2.8, 1.2), archMat);
              mesh.rotation.y = -entity.lineAngle;
              mesh.rotation.z = 0.16;
              y += 1.4;
            } else if (entity.type === 'machine' || entity.type === 'forklift') {
              if (window.ASTHAObjectLibrary) {
                mesh = window.ASTHAObjectLibrary.create(
                  entity.type === 'forklift' ? 'FORKLIFT' : entity.source.machineType,
                  w, h, d, entity.source
                );
              }
            } else if (entity.type === 'dock') {
              y += h / 2;
              mesh = new THREE.Mesh(getBox(w, h, d), dockMat);
            }

            if (!mesh) return;

            mesh.position.set(entity.position.x, y, entity.position.z);
            if (!['wall', 'path', 'stairs', 'zone'].includes(entity.type)) {
              mesh.rotation.y = entity.rotationY;
            }

            mesh.traverse(child => {
              if (child.isMesh) {
                child.castShadow = true;
                child.receiveShadow = true;
              }
            });

            scene.add(mesh);

            if (['wall', 'path', 'stairs'].includes(entity.type)) {
              minX = Math.min(minX, entity.source.x1 * scale, entity.source.x2 * scale) - d / 2;
              maxX = Math.max(maxX, entity.source.x1 * scale, entity.source.x2 * scale) + d / 2;
              minZ = Math.min(minZ, entity.source.y1 * scale, entity.source.y2 * scale) - d / 2;
              maxZ = Math.max(maxZ, entity.source.y1 * scale, entity.source.y2 * scale) + d / 2;
            } else {
              const boundsYaw = entity.type === 'zone' ? 0 : (entity.rotationY || 0);
              const halfX = Math.abs(Math.cos(boundsYaw)) * w / 2 + Math.abs(Math.sin(boundsYaw)) * d / 2;
              const halfZ = Math.abs(Math.sin(boundsYaw)) * w / 2 + Math.abs(Math.cos(boundsYaw)) * d / 2;
              minX = Math.min(minX, entity.position.x - halfX);
              maxX = Math.max(maxX, entity.position.x + halfX);
              minZ = Math.min(minZ, entity.position.z - halfZ);
              maxZ = Math.max(maxZ, entity.position.z + halfZ);
            }
            maxH = Math.max(maxH, y + h);
          } catch(err) {}
        });

        const itemsByShelf = {};
        (items || []).forEach(item => {
          const loc = (item.location || '').split('-')[0].trim();
          if (loc) {
            if (!itemsByShelf[loc]) itemsByShelf[loc] = [];
            itemsByShelf[loc].push(item);
          }
        });

        cadShelves.forEach(sh => {
          const shelfGroup = new THREE.Group();
          shelfGroup.userData = { shelfId: sh.id };

          const rx = sh.x * scale;
          const rz = sh.y * scale;
          const RW = sh.w * scale;
          const RD = sh.h * scale;
          const NS = sh.levels || 3;
          const rackHeight = (sh.shelfHeight || (15 + NS * 30)) * scale;
          const SH = (rackHeight - 15 * scale) / NS;
          const rackBase = 15 * scale;
          const baseY = (sh._floorLevel || 0) * (plan.dimensions?.floorHeight || 160) * scale;
          const loc = sh.id || 'Sem Nome';
          const shelfYaw = -(sh.angle || 0);
          const shelfCx = rx + RW / 2;
          const shelfCz = rz + RD / 2;

          const halfX = Math.abs(Math.cos(shelfYaw)) * RW / 2 + Math.abs(Math.sin(shelfYaw)) * RD / 2;
          const halfZ = Math.abs(Math.sin(shelfYaw)) * RW / 2 + Math.abs(Math.cos(shelfYaw)) * RD / 2;
          minX = Math.min(minX, shelfCx - halfX);
          maxX = Math.max(maxX, shelfCx + halfX);
          minZ = Math.min(minZ, shelfCz - halfZ);
          maxZ = Math.max(maxZ, shelfCz + halfZ);
          maxH = Math.max(maxH, baseY + rackHeight);

          const postH = rackHeight;
          [[rx + 0.08, rz + 0.08], [rx + RW - 0.08, rz + 0.08], [rx + 0.08, rz + RD - 0.08], [rx + RW - 0.08, rz + RD - 0.08]].forEach(p => {
            const post = new THREE.Mesh(new THREE.BoxGeometry(0.12, postH, 0.12), postMat);
            post.position.set(p[0], baseY + postH / 2, p[1]);
            post.castShadow = true;
            shelfGroup.add(post);
          });

          for (let s = 0; s < NS; s++) {
            const by = rackBase + s * SH;
            [rz + 0.08, rz + RD - 0.08].forEach(bz => {
              const beam = new THREE.Mesh(new THREE.BoxGeometry(RW, 0.1, 0.1), beamMat);
              beam.position.set(rx + RW / 2, baseY + by + 0.05, bz);
              beam.castShadow = true;
              shelfGroup.add(beam);
            });
            const board = new THREE.Mesh(new THREE.BoxGeometry(RW - 0.1, 0.07, RD - 0.1), boardMat);
            board.position.set(rx + RW / 2, baseY + by + 0.08, rz + RD / 2);
            board.receiveShadow = true;
            shelfGroup.add(board);
          }

          const lc = document.createElement('canvas');
          lc.width = 256; lc.height = 56;
          const lx = lc.getContext('2d');
          lx.fillStyle = '#0f172a';
          if (lx.roundRect) lx.roundRect(0, 0, 256, 56, 10); else lx.rect(0, 0, 256, 56);
          lx.fill();
          lx.fillStyle = '#f8fafc';
          lx.font = 'bold 20px Inter, -apple-system, sans-serif';
          lx.textAlign = 'center'; lx.textBaseline = 'middle';
          const rackLabel = sh.label || loc;
          lx.fillText(rackLabel.length > 18 ? rackLabel.substring(0, 17) + '…' : rackLabel, 128, 28);
          const ltex = new THREE.CanvasTexture(lc);
          const lbl = new THREE.Mesh(
            new THREE.PlaneGeometry(RW * 0.6, (RW * 0.6) * 56 / 256),
            new THREE.MeshBasicMaterial({ map: ltex, transparent: true, side: THREE.DoubleSide })
          );
          lbl.position.set(rx + RW / 2, baseY + rackHeight + 0.5, rz + RD / 2);
          shelfGroup.add(lbl);

          const itemsInLoc = itemsByShelf[loc] || [];
          const cols = sh.positions || 4;
          const perShelf = Math.max(1, cols);
          const slotW = (RW - 0.3) / perShelf;
          const boxW = Math.min(slotW * 0.78, 1.1);
          const boxH = SH * 0.45;
          const boxD = RD * 0.55;

          itemsInLoc.forEach((item, ii) => {
            let shelf = typeof item.level === 'number' && !isNaN(item.level) ? item.level : Math.floor(ii / perShelf);
            let col = typeof item.position === 'number' && !isNaN(item.position) ? item.position : ii % perShelf;
            if (shelf >= NS) shelf = NS - 1;
            if (col >= perShelf) col = perShelf - 1;

            const bx = rx + 0.15 + slotW * (col + 0.5);
            const by2 = baseY + rackBase + shelf * SH + 0.08 + boxH / 2;
            const bz2 = rz + RD / 2;

            const color = hexToInt(item.color);
            const imat = new THREE.MeshStandardMaterial({ color: color, metalness: 0.15, roughness: 0.55 });
            const box = new THREE.Mesh(new THREE.BoxGeometry(boxW, boxH, boxD), imat);
            box.position.set(bx, by2, bz2);
            box.castShadow = true;
            shelfGroup.add(box);

            const ic = document.createElement('canvas');
            ic.width = 128; ic.height = 32;
            const ix = ic.getContext('2d');
            ix.fillStyle = 'rgba(255,255,255,0.95)';
            if (ix.roundRect) ix.roundRect(0, 0, 128, 32, 6); else ix.rect(0, 0, 128, 32);
            ix.fill();
            ix.fillStyle = '#1e293b';
            ix.font = 'bold 13px Inter, sans-serif';
            ix.textAlign = 'center'; ix.textBaseline = 'middle';
            const code = (item.material || item.code || '').split('—')[0].trim().substring(0, 10);
            ix.fillText(code, 64, 16);
            const itex = new THREE.CanvasTexture(ic);
            const ilbl = new THREE.Mesh(
              new THREE.PlaneGeometry(boxW * 0.9, boxH * 0.4),
              new THREE.MeshBasicMaterial({ map: itex, transparent: true, side: THREE.DoubleSide })
            );
            ilbl.position.set(bx, by2 + boxH / 2 + boxH * 0.22, bz2 + boxD / 2 + 0.01);
            shelfGroup.add(ilbl);
          });

          if (shelfYaw) {
            shelfGroup.children.forEach(obj => {
              const dx = obj.position.x - shelfCx;
              const dz = obj.position.z - shelfCz;
              obj.position.x = shelfCx + Math.cos(shelfYaw) * dx + Math.sin(shelfYaw) * dz;
              obj.position.z = shelfCz - Math.sin(shelfYaw) * dx + Math.cos(shelfYaw) * dz;
              obj.rotation.y += shelfYaw;
            });
          }

          scene.add(shelfGroup);
          shelfMeshes.push(shelfGroup);
        });

        if (!isFinite(minX)) {
          minX = -10; maxX = 10; minZ = -10; maxZ = 10; maxH = 4;
        }

        const centerX = (minX + maxX) / 2;
        const centerZ = (minZ + maxZ) / 2;
        const span = Math.max(maxX - minX, maxZ - minZ, 12);

        floorMesh.geometry.dispose();
        floorMesh.geometry = new THREE.PlaneGeometry(Math.max(2000, span * 40), Math.max(2000, span * 40));
        floorMesh.position.set(centerX, -0.01, centerZ);
        scene.fog = new THREE.Fog(0xf5f7f9, Math.max(40, span * 2), Math.max(300, span * 12));

        const fitDistance = Math.max(span / (2 * Math.tan(camera.fov * Math.PI / 360)) * Math.max(1, 1 / camera.aspect) * 1.25, maxH * 2.2);
        defaultCamPos = {
          x: centerX + fitDistance * 0.55,
          y: maxH * 0.4 + fitDistance * 0.75,
          z: centerZ + fitDistance
        };
        defaultTarget = { x: centerX, y: maxH * 0.4, z: centerZ };

        resetCamera();

        loadingEl.style.opacity = '0';
        setTimeout(() => loadingEl.style.display = 'none', 300);

        try {
          window.parent.postMessage({ type: 'VIEWER_READY' }, '*');
        } catch(e) {}
      }

      function animate() {
        requestAnimationFrame(animate);
        if (controls) controls.update();
        if (renderer && scene && camera) {
          renderer.render(scene, camera);
        }
      }

      window.addEventListener('message', e => {
        if (!e.data || typeof e.data !== 'object') return;
        if (e.data.type === 'LOAD_DATA') {
          if (e.data.name) {
            hudName.textContent = e.data.name;
            hudInfo.style.display = 'flex';
          }
          buildScene(e.data.blueprint, e.data.items);
        } else if (e.data.type === 'RESET_CAMERA') {
          resetCamera();
        } else if (e.data.type === 'SET_FLOOR') {
          currentFloor = Number(e.data.floor) || 0;
          if (currentBlueprint) buildScene(currentBlueprint, currentItems);
        }
      });

      function start() {
        let attempts = 0;
        function tryInit() {
          attempts++;
          if (typeof THREE === 'undefined') {
            if (attempts > 120) {
              if (loadingMsg) loadingMsg.textContent = 'Aguardando carregar biblioteca 3D...';
            }
            setTimeout(tryInit, 50);
            return;
          }
          if (typeof installOrbitControls === 'function') {
            try { installOrbitControls(); } catch(e) {}
          }
          try {
            initThree();
            if (injectedName) {
              hudName.textContent = injectedName;
              hudInfo.style.display = 'flex';
            }
            buildScene(injectedBlueprint, injectedItems);
          } catch(err) {
            console.error('Erro ao montar cena 3D:', err);
            if (loadingMsg) loadingMsg.textContent = 'Erro ao inicializar visualização 3D: ' + (err.message || err);
          }
        }
        tryInit();
      }

      if (document.readyState === 'complete') {
        start();
      } else {
        window.addEventListener('load', start);
      }
    })();
  </script>
</body>
</html>
''';
}

const String _mapModelJs = r'''
(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.ASTHAMapModel = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
  'use strict';

  const SCHEMA_VERSION = 2;
  const MAX_FLOORS = 20;
  const MAX_ENTITIES_PER_TYPE = 2000;
  const MAX_SHELF_LEVELS = 20;
  const MAX_SHELF_POSITIONS = 100;
  const COLLECTIONS = Object.freeze({
    walls: 'wall', doors: 'door', windows: 'window', pillars: 'pillar',
    shelves: 'shelf', stairs: 'stairs', zones: 'zone', paths: 'path',
    machines: 'machine', forklifts: 'forklift', docks: 'dock', addons: 'addon'
  });

  function finite(value, fallback, min = -100000, max = 100000) {
    const number = Number(value);
    return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
  }

  function text(value, fallback = '', max = 120) {
    return typeof value === 'string' ? value.trim().slice(0, max) : fallback;
  }

  function normalizeEntity(raw, type, level, index, unitScale = 1) {
    const source = raw && typeof raw === 'object' ? raw : {};
    const scaled = (value, fallback, min = -100000, max = 100000) => value == null || value === '' ? fallback : finite(Number(value) * unitScale, fallback, min, max);
    const entity = {
      ...source,
      id: text(source.id, `${type}-${level}-${index}`, 80),
      type,
      level,
      visible: source.visible !== false,
      angle: finite(source.angle ?? source.rotation, 0, -Math.PI * 4, Math.PI * 4)
    };
    if ('x' in source || !('x1' in source)) {
      entity.x = scaled(source.x, 0);
      entity.y = scaled(source.y, 0);
    }
    if ('x1' in source || ['wall', 'stairs', 'path', 'zone'].includes(type)) {
      entity.x1 = scaled(source.x1, 0); entity.y1 = scaled(source.y1, 0);
      entity.x2 = scaled(source.x2, entity.x1 + 100); entity.y2 = scaled(source.y2, entity.y1);
    }
    entity.w = scaled(source.w ?? source.width ?? source.size, type === 'pillar' ? 20 : 60, 1, 5000);
    entity.h = scaled(source.h ?? source.depth ?? source.height ?? source.size, type === 'pillar' ? 20 : 40, 1, 5000);
    entity.height3d = scaled(source.height3d ?? source.machineHeight, type === 'machine' ? 70 : 50, 1, 1000);
    if (source.wallThickness != null) entity.wallThickness = scaled(source.wallThickness, 10, 1, 5000);
    if (source.wallHeight != null) entity.wallHeight = scaled(source.wallHeight, 120, 30, 4000);
    entity.label = text(source.label ?? source.name ?? source.id, entity.id, 120);
    entity.color = /^#[0-9a-f]{6}$/i.test(String(source.color || '')) ? source.color : undefined;
    entity.elevation = scaled(source.elevation,0,0,10000);
    if(source.operationClearance!==undefined)entity.operationClearance=scaled(source.operationClearance,0,0,500);
    if(source.maintenanceClearance!==undefined)entity.maintenanceClearance=scaled(source.maintenanceClearance,0,0,500);
    if (type === 'pillar') entity.size = entity.w;
    if (type === 'shelf') {
      entity.levels = Math.round(finite(source.levels, 3, 1, MAX_SHELF_LEVELS));
      entity.shelfHeight = scaled(source.shelfHeight, 15 + entity.levels * 30, 30, 1000);
      entity.positions = Math.round(finite(source.positions, Math.max(1, Math.floor(entity.w/25)), 1, MAX_SHELF_POSITIONS));
      entity.items = (Array.isArray(source.items) ? source.items : []).slice(0, MAX_ENTITIES_PER_TYPE).map((item, itemIndex) => ({
        id: text(item && item.id, `item-${itemIndex}`, 80), material: text(item && (item.material || item.name), '', 200),
        level: Math.round(finite(item && item.level, 1, 1, entity.levels)), position: Math.round(finite(item && item.position, 1, 1, entity.positions)),
        color: /^#[0-9a-f]{6}$/i.test(String(item && item.color || '')) ? item.color : '#3b82f6'
      }));
    }
    if (type === 'addon') {
      entity.name = text(source.name, entity.label, 120);
      entity.fileExt = ['glb', 'gltf', 'obj', 'stl'].includes(String(source.fileExt || '').toLowerCase()) ? String(source.fileExt).toLowerCase() : '';
      entity.fileUrl = /^blob:[^\s"'<>]{1,2048}$/i.test(String(source.fileUrl || '')) ? source.fileUrl : null;
      entity.width = entity.w; entity.height = entity.h;
    }
    return entity;
  }

  function emptyFloor() {
    return Object.fromEntries(Object.keys(COLLECTIONS).map(key => [key, []]));
  }

  function normalizeBlueprint(input) {
    const source = input && typeof input === 'object' && !Array.isArray(input) ? input : {};
    const floorsInput = source.floors && typeof source.floors === 'object' ? source.floors : {0: {}};
    const unitScale = source.units === 'm' ? 100 : 1;
    const floors = {};
    Object.keys(floorsInput).slice(0, MAX_FLOORS).forEach(levelKey => {
      const level = Number.parseInt(levelKey, 10);
      if (!Number.isInteger(level) || level < 0 || level >= MAX_FLOORS) return;
      const floorSource = floorsInput[levelKey] && typeof floorsInput[levelKey] === 'object' ? floorsInput[levelKey] : {};
      const floor = emptyFloor();
      Object.entries(COLLECTIONS).forEach(([collection, type]) => {
        const values = Array.isArray(floorSource[collection]) ? floorSource[collection].slice(0, MAX_ENTITIES_PER_TYPE) : [];
        floor[collection] = values.map((value, index) => normalizeEntity(value, type, level, index, unitScale));
      });
      floors[level] = floor;
    });
    if (!floors[0]) floors[0] = emptyFloor();
    return {
      schemaVersion: SCHEMA_VERSION,
      units: 'cm',
      name: text(source.name, '', 120),
      config: source.config && typeof source.config === 'object' ? {...source.config,
        wallHeight: scaledConfig(source.config.wallHeight, 120, unitScale, 60, 4000)} : {},
      floors
    };
  }

  function map2DTo3D(x, y, elevation = 0, scale = 1) {
    return {x: finite(x, 0) * scale, y: finite(elevation, 0) * scale, z: finite(y, 0) * scale};
  }

  function createScenePlan(input, options = {}) {
    const blueprint = normalizeBlueprint(input);
    const scale = finite(options.scale, 1, 0.001, 100);
    const dimensions = sceneDimensions(blueprint);
    const floorHeight = dimensions.floorHeight;
    const entities = [];
    Object.entries(blueprint.floors).forEach(([levelKey, floor]) => {
      const level = Number(levelKey); const elevation = level * floorHeight;
      Object.entries(COLLECTIONS).forEach(([collection, type]) => {
        floor[collection].forEach(entity => {
          if (!entity.visible) return;
          const isRectangle = ['shelf','machine','forklift','dock','addon'].includes(type);
          const position = entity.x1 === undefined
            ? map2DTo3D(entity.x + (isRectangle ? entity.w/2 : 0), entity.y + (isRectangle ? entity.h/2 : 0), elevation + finite(entity.elevation,0,0,10000), scale)
            : map2DTo3D((entity.x1 + entity.x2) / 2, (entity.y1 + entity.y2) / 2, elevation, scale);
          entities.push({id: entity.id, type, level, position, rotationY: -entity.angle,
            width: entity.w * scale, depth: entity.h * scale, height: (type === 'shelf' ? entity.shelfHeight : ['wall','pillar'].includes(type) ? (entity.wallHeight || dimensions.wallHeight) : entity.height3d) * scale,
            length: entity.x1 === undefined ? undefined : Math.hypot(entity.x2-entity.x1, entity.y2-entity.y1) * scale,
            lineAngle: entity.x1 === undefined ? undefined : Math.atan2(entity.y2-entity.y1, entity.x2-entity.x1),
            color: entity.color, label: entity.label, source: entity});
        });
      });
    });
    return {schemaVersion: SCHEMA_VERSION, blueprint, entities, dimensions};
  }

  function sceneDimensions(input) {
    let wallHeight = Math.max(120, Number(input.config?.wallHeight) || 120);
    for (const floor of Object.values(input.floors || {})) {
      for (const shelf of floor.shelves || []) if (shelf.visible !== false) wallHeight = Math.max(wallHeight, (Number(shelf.shelfHeight) || 15 + (shelf.levels || 3) * 30) + 20);
      for (const wall of floor.walls || []) wallHeight = Math.max(wallHeight, Number(wall.wallHeight) || 0);
    }
    return {wallHeight, floorHeight:Math.max(160, wallHeight + 20)};
  }

  function transformEntity(entity, values) {
    const result = {...entity};
    const ranges = {x:[-100000,100000],y:[-100000,100000],width:[1,5000],depth:[1,5000],height:[['machine','forklift'].includes(entity.type)?1:30,['wall','pillar'].includes(entity.type)?4000:1000],rotation:[-720,720]};
    for (const [key,[min,max]] of Object.entries(ranges)) {
      const n=Number(values[key]);
      if(values[key]==='' || !Number.isFinite(n) || n<min || n>max) throw new Error('Dimensões inválidas: '+key);
    }
    result.label = text(values.label, entity.label, 120);
    const angle=Number(values.rotation)*Math.PI/180;
    if(entity.x1 !== undefined) {
      result.x1=Number(values.x);result.y1=Number(values.y);
      if(entity.type==='zone') {result.x2=result.x1+Number(values.width);result.y2=result.y1+Number(values.depth);}
      else {result.x2=result.x1+Math.cos(angle)*Number(values.width);result.y2=result.y1+Math.sin(angle)*Number(values.width);}
    } else {result.x=Number(values.x);result.y=Number(values.y);}
    result.w=Number(values.width);result.h=Number(values.depth);result.angle=angle;
    if(entity.type==='wall')result.wallThickness=Number(values.depth);
    if(entity.type==='shelf')result.shelfHeight=Number(values.height);
    else if(['wall','pillar'].includes(entity.type))result.wallHeight=Number(values.height);
    else result.height3d=Number(values.height);
    if(entity.type==='pillar')result.size=result.w;
    if(entity.type==='addon'){result.width=result.w;result.height=result.h;}
    return result;
  }

  function scaledConfig(value, fallback, unitScale, min, max) {
    if (value == null || value === '') return fallback;
    return finite(Number(value) * unitScale, fallback, min, max);
  }

  return {SCHEMA_VERSION, COLLECTIONS, MAX_FLOORS, MAX_ENTITIES_PER_TYPE, MAX_SHELF_LEVELS, MAX_SHELF_POSITIONS, emptyFloor, normalizeEntity, normalizeBlueprint, map2DTo3D, createScenePlan, sceneDimensions, transformEntity};
});
''';

const String _objectLibraryJs = r'''
window.ASTHAObjectLibrary = (() => {
  const entries = {
    GENERIC_MACHINE: {name:'Centro de usinagem CNC',tool:'machine',w:180,d:140,height:210},
    LATHE: {name:'Torno industrial',tool:'machine',w:240,d:100,height:150},
    FURNACE: {name:'Forno industrial',tool:'machine',w:160,d:150,height:220},
    PRESS: {name:'Prensa hidráulica',tool:'machine',w:140,d:110,height:230},
    CONVEYOR: {name:'Esteira transportadora',tool:'machine',w:300,d:90,height:100},
    CRATE: {name:'Caixa de madeira',tool:'machine',w:100,d:80,height:90},
    CARTON: {name:'Caixa de papelão',tool:'machine',w:60,d:40,height:45},
    PALLET: {name:'Palete',tool:'machine',w:120,d:100,height:15},
    FORKLIFT: {name:'Empilhadeira',tool:'forklift',w:300,d:120,height:220}
    ,MILL: {id:'ASTHA-3D-001',category:'Usinagem e metalurgia',name:'Fresadora universal',tool:'machine',w:180,d:150,height:220,tags:['usinagem','fresa']}
    ,DRILL: {id:'ASTHA-3D-003',category:'Usinagem e metalurgia',name:'Furadeira de coluna',tool:'machine',w:70,d:90,height:180,tags:['usinagem','broca']}
    ,BANDSAW: {id:'ASTHA-3D-007',category:'Usinagem e metalurgia',name:'Serra de fita',tool:'machine',w:160,d:90,height:160,tags:['corte','serra']}
    ,TANK: {id:'ASTHA-3D-027',category:'Processamento industrial',name:'Tanque agitado',tool:'machine',w:150,d:150,height:240,tags:['mistura','reservatorio']}
    ,SILO: {id:'ASTHA-3D-033',category:'Processamento industrial',name:'Silo',tool:'machine',w:200,d:200,height:500,tags:['graos','armazenagem']}
    ,ROBOT: {id:'ASTHA-3D-053',category:'Robótica e células automatizadas',name:'Braço robótico de seis eixos',tool:'machine',w:180,d:140,height:220,tags:['automacao','robo']}
    ,SCARA: {id:'ASTHA-3D-054',category:'Robótica e células automatizadas',name:'Robô SCARA',tool:'machine',w:120,d:100,height:150,tags:['automacao','robo']}
    ,ROLLER: {id:'ASTHA-3D-065',category:'Transportadores e transferência',name:'Transportador de roletes livres',tool:'machine',w:300,d:80,height:90,tags:['esteira','transportador']}
    ,ROLLER_MOTOR: {id:'ASTHA-3D-066',category:'Transportadores e transferência',name:'Transportador de roletes motorizados',tool:'machine',w:300,d:100,height:90,tags:['esteira','motor']}
    ,AGV: {id:'ASTHA-3D-085',category:'Movimentação e elevação',name:'AGV',tool:'machine',w:130,d:90,height:45,tags:['veiculo','autonomo','logistica']}
    ,COMPRESSOR: {id:'ASTHA-3D-119',category:'Utilidades industriais',name:'Compressor de parafuso',tool:'machine',w:150,d:100,height:140,tags:['ar comprimido','utilidades']}
    ,PUMP: {id:'ASTHA-3D-124',category:'Utilidades industriais',name:'Bomba centrífuga',tool:'machine',w:140,d:70,height:90,tags:['agua','motor','utilidades']}
    ,EXTINGUISHER: {id:'ASTHA-3D-183',category:'Segurança industrial',name:'Extintor',tool:'machine',w:35,d:35,height:80,tags:['incendio','seguranca']}
    ,FENCE: {id:'ASTHA-3D-190',category:'Segurança industrial',name:'Cerca de proteção de máquinas',tool:'machine',w:200,d:25,height:200,tags:['grade','barreira','seguranca']}
  };
  const aliases=Object.fromEntries(Object.entries(entries).filter(([,item])=>item.id).map(([key,item])=>[key,item.id]));
  const catalog=Object.freeze({...Object.fromEntries(Object.entries(entries).filter(([,item])=>!item.id).map(([key,item])=>[key,Object.freeze({
    ...item,id:item.id||'ASTHA-LEGACY-'+key,version:'1.0.0',category:item.category||'Modelos básicos',
    geometryType:'parametric',dimensions:{length:item.w/100,width:item.d/100,height:item.height/100,unit:'m'},
    capabilities:{resizable:true,rotatable:true,snap:false,connectors:false,collision:false,assetLink:false},
    origin:'ASTHA · geometria procedural autoral',tags:item.tags||[]
  })])),...(window.ASTHAIndustrialCatalog?.byId||{})});
  const resolve=key=>aliases[key]||key;
  let pending='GENERIC_MACHINE';
  function select(key) {key=resolve(key); if(!catalog[key])return;pending=key;if(typeof window.setCadTool==='function')window.setCadTool(catalog[key].tool); }
  function definition(tool){const key=tool==='forklift'?'FORKLIFT':(catalog[pending]?.tool===tool?pending:'GENERIC_MACHINE');return {...catalog[key],key};}
  function create(key,width,height,depth,source={}){
    key=resolve(key);
    const T=window.THREE;if(!T)throw Error('Three.js indisponível');key=catalog[key]?key:'GENERIC_MACHINE';const model=new T.Group();
    const material=color=>new T.MeshStandardMaterial({color,roughness:.55,metalness:.25});
    const steel=material('#667b8e'),dark=material('#25333e'),silver=material('#c2ccd3'),blue=material('#487c91'),orange=material('#e8a333'),wood=material('#bb8c55'),paper=material('#c4a077'),glass=new T.MeshStandardMaterial({color:'#3d6579',roughness:.2,metalness:.2});
    function box(x,y,z,w,h,d,mat){const mesh=new T.Mesh(new T.BoxGeometry(w,h,d),mat);mesh.position.set(x,y,z);model.add(mesh);return mesh;}
    function cylinder(x,y,z,r,length,mat,axis='y'){const mesh=new T.Mesh(new T.CylinderGeometry(r,r,length,20),mat);if(axis==='x')mesh.rotation.z=Math.PI/2;if(axis==='z')mesh.rotation.x=Math.PI/2;mesh.position.set(x,y,z);model.add(mesh);return mesh;}
    function feet(){for(const x of [-.36,.36])for(const z of [-.32,.32])box(x,.08,z,.12,.16,.12,dark);}
    function console(x,y,z){box(x,y,z,.18,.23,.08,steel);box(x,y+.03,z+.045,.12,.10,.015,glass);for(const dx of [-.04,0,.04])cylinder(x+dx,y-.065,z+.05,.012,.015,orange,'z');}
    if(key==='FORKLIFT'){
      box(-.10,.28,0,.64,.28,.64,orange);box(-.34,.45,0,.18,.27,.64,orange);
      for(const x of [-.29,.20])for(const z of [-.32,.32]){cylinder(x,.18,z,.17,.10,dark,'z');cylinder(x,.18,z*1.15,.07,.012,silver,'z');}
      box(-.04,.47,0,.22,.08,.24,dark);box(-.14,.59,0,.07,.24,.24,dark);
      for(const x of [-.28,.20])for(const z of [-.28,.28])box(x,.70,z,.035,.55,.035,dark);box(-.04,1,0,.57,.04,.66,dark);
      for(const z of [-.23,.23])box(.35,.61,z,.055,.90,.055,steel);box(.36,.38,0,.08,.08,.58,steel);
      for(const z of [-.20,.20])box(.61,.13,z,.53,.035,.06,silver);
      cylinder(.14,.58,0,.11,.025,dark,'x');
    }else if(key==='LATHE'){
      feet();box(0,.27,0,.86,.22,.55,blue);box(0,.48,0,.94,.13,.38,steel);
      box(-.34,.71,0,.24,.39,.50,blue);cylinder(-.18,.74,0,.15,.10,silver,'x');cylinder(.03,.74,0,.06,.38,silver,'x');
      box(.34,.65,0,.20,.19,.26,steel);box(.08,.61,.13,.20,.14,.28,blue);cylinder(.08,.59,.31,.065,.04,dark,'z');console(-.34,.82,.28);
    }else if(key==='FURNACE'){
      feet();box(0,.55,0,.78,.87,.65,steel);box(0,.54,.34,.66,.67,.07,dark);box(0,.55,.385,.48,.47,.025,orange);box(0,.55,.405,.37,.36,.025,dark);
      box(.26,.57,.43,.035,.22,.035,silver);cylinder(-.23,1.07,-.18,.085,.24,steel);console(.29,.90,.38);
    }else if(key==='PRESS'){
      feet();box(0,.18,0,.87,.16,.66,blue);for(const x of [-.35,.35])box(x,.62,0,.12,.90,.5,blue);
      box(0,1.02,0,.82,.15,.55,blue);cylinder(0,.82,0,.10,.27,silver);box(0,.68,0,.55,.09,.48,steel);box(0,.40,0,.64,.10,.5,silver);console(.43,.72,.29);
    }else if(key==='MILL'||key==='DRILL'){
      box(0,.08,0,.7,.16,.7,blue);box(0,.52,-.20,.24,.90,.24,blue);
      box(0,.65,.09,.65,.09,.55,silver);box(0,.98,0,.32,.21,.46,blue);cylinder(0,.82,.15,.04,.22,silver);
      if(key==='MILL'){box(0,.40,.07,.46,.30,.32,steel);cylinder(.30,.53,.36,.075,.045,dark,'z');console(-.30,.83,.06);}
      else{cylinder(0,.40,-.20,.08,.65,silver);box(.25,.93,.10,.32,.025,.025,dark);}
    }else if(key==='BANDSAW'){
      feet();box(0,.28,0,.9,.35,.55,blue);box(0,.51,0,.9,.07,.60,silver);
      box(-.37,.78,0,.14,.52,.3,blue);box(.37,.78,0,.14,.52,.3,blue);box(0,1.02,0,.87,.13,.3,blue);
      box(0,.69,.02,.7,.02,.06,dark);cylinder(-.32,.91,.17,.10,.04,silver,'z');cylinder(.32,.91,.17,.10,.04,silver,'z');
    }else if(key==='TANK'||key==='SILO'){
      for(const x of [-.30,.30])for(const z of [-.30,.30])box(x,.25,z,.05,.5,.05,steel);
      cylinder(0,.74,0,.43,.70,silver);cylinder(0,1.10,0,.44,.035,steel);
      if(key==='TANK'){cylinder(0,1.22,0,.10,.22,blue);box(0,1.11,0,.55,.04,.10,blue);cylinder(.42,.52,0,.045,.18,steel,'x');}
      else{const cone=new T.Mesh(new T.CylinderGeometry(.43,.075,.35,20),silver);cone.position.y=.23;model.add(cone);cylinder(0,.045,0,.08,.09,steel);for(let i=0;i<12;i++)box(.46,.2+i*.08,0,.04,.025,.35,orange);}
    }else if(key==='ROBOT'||key==='SCARA'){
      cylinder(0,.08,0,.30,.16,dark);cylinder(0,.27,0,.18,.30,orange);
      if(key==='SCARA'){box(0,.73,0,.17,.72,.18,blue);box(.27,1.02,0,.60,.11,.16,orange);cylinder(.54,.96,0,.10,.20,dark);box(.70,.96,0,.36,.10,.13,orange);cylinder(.87,.78,0,.035,.36,silver);}
      else{cylinder(0,.48,0,.16,.26,dark,'z');const arm=box(.13,.73,0,.18,.57,.19,orange);arm.rotation.z=-.45;cylinder(.25,.99,0,.13,.22,dark,'z');const fore=box(.47,1.02,0,.52,.14,.16,orange);fore.rotation.z=.15;cylinder(.73,1.06,0,.09,.16,dark,'z');box(.81,.97,0,.10,.22,.10,silver);for(const z of [-.065,.065])box(.83,.84,z,.12,.10,.035,dark);}
    }else if(key==='AGV'){
      box(0,.22,0,.90,.30,.65,orange);box(0,.40,0,.8,.06,.60,silver);for(const x of [-.30,.30])for(const z of [-.33,.33])cylinder(x,.14,z,.12,.08,dark,'z');cylinder(.32,.45,0,.065,.10,dark);box(-.46,.24,0,.015,.08,.38,glass);
    }else if(key==='COMPRESSOR'){
      feet();box(0,.54,0,.90,.78,.66,blue);for(let i=0;i<7;i++)box(-.20,.37+i*.065,.34,.35,.025,.025,dark);console(.25,.72,.34);cylinder(.35,1.01,-.15,.045,.17,silver);box(0,.15,0,1,.08,.74,steel);
    }else if(key==='PUMP'){
      box(0,.08,0,1,.16,.55,steel);cylinder(-.23,.37,0,.19,.44,blue,'x');for(let i=0;i<8;i++)box(-.23,.48,-.15+i*.042,.40,.035,.022,steel);cylinder(.18,.32,0,.20,.20,blue,'x');cylinder(.20,.54,0,.065,.30,silver);cylinder(.40,.32,0,.065,.25,silver,'x');cylinder(.54,.32,0,.11,.035,steel,'x');
    }else if(key==='EXTINGUISHER'){
      const red=material('#c94141');cylinder(0,.42,0,.18,.66,red);cylinder(0,.78,0,.065,.08,dark);box(.06,.83,0,.27,.03,.05,dark);box(-.16,.48,0,.025,.55,.025,dark);box(0,.45,.18,.18,.22,.015,silver);
    }else if(key==='FENCE'){
      for(const x of [-.47,.47]){box(x,.52,0,.045,1.04,.045,orange);box(x,.025,0,.15,.05,.20,steel);}for(const y of [.15,.96])box(0,y,0,.94,.025,.025,orange);for(let i=0;i<16;i++)box(-.44+i*.059,.55,0,.009,.80,.009,steel);for(let i=0;i<10;i++)box(0,.16+i*.08,0,.89,.008,.008,steel);
    }else if(key==='CONVEYOR'||key==='ROLLER'||key==='ROLLER_MOTOR'){
      for(const x of [-.4,.4])for(const z of [-.3,.3])box(x,.28,z,.055,.56,.055,steel);
      box(0,.6,0,1,.10,.70,dark);for(let i=0;i<12;i++)cylinder(-.46+i*.083,.665,0,.035,.68,silver,'z');for(const z of [-.37,.37])box(0,.68,z,1,.07,.035,blue);
      if(key==='ROLLER_MOTOR'){cylinder(-.34,.52,.45,.08,.19,blue,'z');box(-.34,.48,.32,.14,.1,.1,steel);}
    }else if(key==='CRATE'||key==='CARTON'){
      box(0,.5,0,.94,.94,.74,key==='CRATE'?wood:paper);
      if(key==='CRATE'){for(const x of [-.39,.39])for(const z of [-.395,.395])box(x,.5,z,.10,1,.035,wood);for(const y of [.08,.33,.66,.92])for(const z of [-.395,.395])box(0,y,z,1,.06,.04,wood);}
      else{box(0,.978,0,.11,.018,.75,wood);box(0,.5,.38,.12,.94,.015,wood);box(.24,.55,.39,.23,.20,.01,silver);}
    }else if(key==='PALLET'){
      for(const x of [-.4,0,.4])for(const z of [-.32,0,.32])box(x,.10,z,.15,.12,.16,wood);
      for(let i=0;i<5;i++)box(0,.20,-.4+i*.2,1,.06,.13,wood);for(const x of [-.4,0,.4])box(x,.025,0,.15,.05,.94,wood);
    }else{
      feet();box(0,.24,0,.98,.22,.74,blue);box(0,.66,-.24,.98,.67,.28,steel);for(const x of [-.41,.41])box(x,.66,.04,.15,.67,.65,blue);
      box(0,.97,0,.98,.13,.77,blue);box(0,.64,.385,.63,.56,.045,silver);box(0,.70,.415,.49,.29,.015,glass);box(.25,.56,.45,.025,.14,.025,dark);console(.48,.78,.43);
    }
    model.updateMatrixWorld(true);const bounds=new T.Box3().setFromObject(model),size=bounds.getSize(new T.Vector3()),center=bounds.getCenter(new T.Vector3());const wrapper=new T.Group();model.position.set(-center.x,-bounds.min.y,-center.z);wrapper.add(model);wrapper.scale.set(Math.max(.001,width)/size.x,Math.max(.001,height)/size.y,Math.max(.001,depth)/size.z);return wrapper;
  }
  return {catalog,select,definition,create,resolve};
})();
''';


const String _orbitControlsJs = r'''
function installOrbitControls() {
  if (typeof THREE === "undefined") return false;
  if (typeof THREE.OrbitControls !== "undefined") return true;
( function () {
const _changeEvent = {
type: 'change'
};
const _startEvent = {
type: 'start'
};
const _endEvent = {
type: 'end'
};
class OrbitControls extends THREE.EventDispatcher {
constructor( object, domElement ) {
super();
if ( domElement === undefined ) console.warn( 'THREE.OrbitControls: The second parameter "domElement" is now mandatory.' );
if ( domElement === document ) console.error( 'THREE.OrbitControls: "document" should not be used as the target "domElement". Please use "renderer.domElement" instead.' );
this.object = object;
this.domElement = domElement;
this.enabled = true;
this.target = new THREE.Vector3();
this.minDistance = 0;
this.maxDistance = Infinity;
this.minZoom = 0;
this.maxZoom = Infinity;
this.minPolarAngle = 0;
this.maxPolarAngle = Math.PI;
this.minAzimuthAngle = - Infinity;
this.maxAzimuthAngle = Infinity;
this.enableDamping = false;
this.dampingFactor = 0.05;
this.enableZoom = true;
this.zoomSpeed = 1.0;
this.enableRotate = true;
this.rotateSpeed = 1.0;
this.enablePan = true;
this.panSpeed = 1.0;
this.screenSpacePanning = true;
this.keyPanSpeed = 7.0;
this.autoRotate = false;
this.autoRotateSpeed = 2.0;
this.keys = {
LEFT: 'ArrowLeft',
UP: 'ArrowUp',
RIGHT: 'ArrowRight',
BOTTOM: 'ArrowDown'
};
this.mouseButtons = {
LEFT: THREE.MOUSE.ROTATE,
MIDDLE: THREE.MOUSE.DOLLY,
RIGHT: THREE.MOUSE.PAN
};
this.touches = {
ONE: THREE.TOUCH.ROTATE,
TWO: THREE.TOUCH.DOLLY_PAN
};
this.target0 = this.target.clone();
this.position0 = this.object.position.clone();
this.zoom0 = this.object.zoom;
this._domElementKeyEvents = null;
this.getPolarAngle = function () {
return spherical.phi;
};
this.getAzimuthalAngle = function () {
return spherical.theta;
};
this.listenToKeyEvents = function ( domElement ) {
domElement.addEventListener( 'keydown', onKeyDown );
this._domElementKeyEvents = domElement;
};
this.saveState = function () {
scope.target0.copy( scope.target );
scope.position0.copy( scope.object.position );
scope.zoom0 = scope.object.zoom;
};
this.reset = function () {
scope.target.copy( scope.target0 );
scope.object.position.copy( scope.position0 );
scope.object.zoom = scope.zoom0;
scope.object.updateProjectionMatrix();
scope.dispatchEvent( _changeEvent );
scope.update();
state = STATE.NONE;
};
this.update = function () {
const offset = new THREE.Vector3();
const quat = new THREE.Quaternion().setFromUnitVectors( object.up, new THREE.Vector3( 0, 1, 0 ) );
const quatInverse = quat.clone().invert();
const lastPosition = new THREE.Vector3();
const lastQuaternion = new THREE.Quaternion();
const twoPI = 2 * Math.PI;
return function update() {
const position = scope.object.position;
offset.copy( position ).sub( scope.target );
offset.applyQuaternion( quat );
spherical.setFromVector3( offset );
if ( scope.autoRotate && state === STATE.NONE ) {
rotateLeft( getAutoRotationAngle() );
}
if ( scope.enableDamping ) {
spherical.theta += sphericalDelta.theta * scope.dampingFactor;
spherical.phi += sphericalDelta.phi * scope.dampingFactor;
} else {
spherical.theta += sphericalDelta.theta;
spherical.phi += sphericalDelta.phi;
}
let min = scope.minAzimuthAngle;
let max = scope.maxAzimuthAngle;
if ( isFinite( min ) && isFinite( max ) ) {
if ( min < - Math.PI ) min += twoPI; else if ( min > Math.PI ) min -= twoPI;
if ( max < - Math.PI ) max += twoPI; else if ( max > Math.PI ) max -= twoPI;
if ( min <= max ) {
spherical.theta = Math.max( min, Math.min( max, spherical.theta ) );
} else {
spherical.theta = spherical.theta > ( min + max ) / 2 ? Math.max( min, spherical.theta ) : Math.min( max, spherical.theta );
}
}
spherical.phi = Math.max( scope.minPolarAngle, Math.min( scope.maxPolarAngle, spherical.phi ) );
spherical.makeSafe();
spherical.radius *= scale;
spherical.radius = Math.max( scope.minDistance, Math.min( scope.maxDistance, spherical.radius ) );
if ( scope.enableDamping === true ) {
scope.target.addScaledVector( panOffset, scope.dampingFactor );
} else {
scope.target.add( panOffset );
}
offset.setFromSpherical( spherical );
offset.applyQuaternion( quatInverse );
position.copy( scope.target ).add( offset );
scope.object.lookAt( scope.target );
if ( scope.enableDamping === true ) {
sphericalDelta.theta *= 1 - scope.dampingFactor;
sphericalDelta.phi *= 1 - scope.dampingFactor;
panOffset.multiplyScalar( 1 - scope.dampingFactor );
} else {
sphericalDelta.set( 0, 0, 0 );
panOffset.set( 0, 0, 0 );
}
scale = 1;
if ( zoomChanged || lastPosition.distanceToSquared( scope.object.position ) > EPS || 8 * ( 1 - lastQuaternion.dot( scope.object.quaternion ) ) > EPS ) {
scope.dispatchEvent( _changeEvent );
lastPosition.copy( scope.object.position );
lastQuaternion.copy( scope.object.quaternion );
zoomChanged = false;
return true;
}
return false;
};
}();
this.dispose = function () {
scope.domElement.removeEventListener( 'contextmenu', onContextMenu );
scope.domElement.removeEventListener( 'pointerdown', onPointerDown );
scope.domElement.removeEventListener( 'wheel', onMouseWheel );
scope.domElement.removeEventListener( 'touchstart', onTouchStart );
scope.domElement.removeEventListener( 'touchend', onTouchEnd );
scope.domElement.removeEventListener( 'touchmove', onTouchMove );
scope.domElement.ownerDocument.removeEventListener( 'pointermove', onPointerMove );
scope.domElement.ownerDocument.removeEventListener( 'pointerup', onPointerUp );
if ( scope._domElementKeyEvents !== null ) {
scope._domElementKeyEvents.removeEventListener( 'keydown', onKeyDown );
}
};
const scope = this;
const STATE = {
NONE: - 1,
ROTATE: 0,
DOLLY: 1,
PAN: 2,
TOUCH_ROTATE: 3,
TOUCH_PAN: 4,
TOUCH_DOLLY_PAN: 5,
TOUCH_DOLLY_ROTATE: 6
};
let state = STATE.NONE;
const EPS = 0.000001;
const spherical = new THREE.Spherical();
const sphericalDelta = new THREE.Spherical();
let scale = 1;
const panOffset = new THREE.Vector3();
let zoomChanged = false;
const rotateStart = new THREE.Vector2();
const rotateEnd = new THREE.Vector2();
const rotateDelta = new THREE.Vector2();
const panStart = new THREE.Vector2();
const panEnd = new THREE.Vector2();
const panDelta = new THREE.Vector2();
const dollyStart = new THREE.Vector2();
const dollyEnd = new THREE.Vector2();
const dollyDelta = new THREE.Vector2();
function getAutoRotationAngle() {
return 2 * Math.PI / 60 / 60 * scope.autoRotateSpeed;
}
function getZoomScale() {
return Math.pow( 0.95, scope.zoomSpeed );
}
function rotateLeft( angle ) {
sphericalDelta.theta -= angle;
}
function rotateUp( angle ) {
sphericalDelta.phi -= angle;
}
const panLeft = function () {
const v = new THREE.Vector3();
return function panLeft( distance, objectMatrix ) {
v.setFromMatrixColumn( objectMatrix, 0 );
v.multiplyScalar( - distance );
panOffset.add( v );
};
}();
const panUp = function () {
const v = new THREE.Vector3();
return function panUp( distance, objectMatrix ) {
if ( scope.screenSpacePanning === true ) {
v.setFromMatrixColumn( objectMatrix, 1 );
} else {
v.setFromMatrixColumn( objectMatrix, 0 );
v.crossVectors( scope.object.up, v );
}
v.multiplyScalar( distance );
panOffset.add( v );
};
}();
const pan = function () {
const offset = new THREE.Vector3();
return function pan( deltaX, deltaY ) {
const element = scope.domElement;
if ( scope.object.isPerspectiveCamera ) {
const position = scope.object.position;
offset.copy( position ).sub( scope.target );
let targetDistance = offset.length();
targetDistance *= Math.tan( scope.object.fov / 2 * Math.PI / 180.0 );
panLeft( 2 * deltaX * targetDistance / element.clientHeight, scope.object.matrix );
panUp( 2 * deltaY * targetDistance / element.clientHeight, scope.object.matrix );
} else if ( scope.object.isOrthographicCamera ) {
panLeft( deltaX * ( scope.object.right - scope.object.left ) / scope.object.zoom / element.clientWidth, scope.object.matrix );
panUp( deltaY * ( scope.object.top - scope.object.bottom ) / scope.object.zoom / element.clientHeight, scope.object.matrix );
} else {
console.warn( 'WARNING: OrbitControls.js encountered an unknown camera type - pan disabled.' );
scope.enablePan = false;
}
};
}();
function dollyOut( dollyScale ) {
if ( scope.object.isPerspectiveCamera ) {
scale /= dollyScale;
} else if ( scope.object.isOrthographicCamera ) {
scope.object.zoom = Math.max( scope.minZoom, Math.min( scope.maxZoom, scope.object.zoom * dollyScale ) );
scope.object.updateProjectionMatrix();
zoomChanged = true;
} else {
console.warn( 'WARNING: OrbitControls.js encountered an unknown camera type - dolly/zoom disabled.' );
scope.enableZoom = false;
}
}
function dollyIn( dollyScale ) {
if ( scope.object.isPerspectiveCamera ) {
scale *= dollyScale;
} else if ( scope.object.isOrthographicCamera ) {
scope.object.zoom = Math.max( scope.minZoom, Math.min( scope.maxZoom, scope.object.zoom / dollyScale ) );
scope.object.updateProjectionMatrix();
zoomChanged = true;
} else {
console.warn( 'WARNING: OrbitControls.js encountered an unknown camera type - dolly/zoom disabled.' );
scope.enableZoom = false;
}
}
function handleMouseDownRotate( event ) {
rotateStart.set( event.clientX, event.clientY );
}
function handleMouseDownDolly( event ) {
dollyStart.set( event.clientX, event.clientY );
}
function handleMouseDownPan( event ) {
panStart.set( event.clientX, event.clientY );
}
function handleMouseMoveRotate( event ) {
rotateEnd.set( event.clientX, event.clientY );
rotateDelta.subVectors( rotateEnd, rotateStart ).multiplyScalar( scope.rotateSpeed );
const element = scope.domElement;
rotateLeft( 2 * Math.PI * rotateDelta.x / element.clientHeight );
rotateUp( 2 * Math.PI * rotateDelta.y / element.clientHeight );
rotateStart.copy( rotateEnd );
scope.update();
}
function handleMouseMoveDolly( event ) {
dollyEnd.set( event.clientX, event.clientY );
dollyDelta.subVectors( dollyEnd, dollyStart );
if ( dollyDelta.y > 0 ) {
dollyOut( getZoomScale() );
} else if ( dollyDelta.y < 0 ) {
dollyIn( getZoomScale() );
}
dollyStart.copy( dollyEnd );
scope.update();
}
function handleMouseMovePan( event ) {
panEnd.set( event.clientX, event.clientY );
panDelta.subVectors( panEnd, panStart ).multiplyScalar( scope.panSpeed );
pan( panDelta.x, panDelta.y );
panStart.copy( panEnd );
scope.update();
}
function handleMouseUp( ) {
}
function handleMouseWheel( event ) {
if ( event.deltaY < 0 ) {
dollyIn( getZoomScale() );
} else if ( event.deltaY > 0 ) {
dollyOut( getZoomScale() );
}
scope.update();
}
function handleKeyDown( event ) {
let needsUpdate = false;
switch ( event.code ) {
case scope.keys.UP:
pan( 0, scope.keyPanSpeed );
needsUpdate = true;
break;
case scope.keys.BOTTOM:
pan( 0, - scope.keyPanSpeed );
needsUpdate = true;
break;
case scope.keys.LEFT:
pan( scope.keyPanSpeed, 0 );
needsUpdate = true;
break;
case scope.keys.RIGHT:
pan( - scope.keyPanSpeed, 0 );
needsUpdate = true;
break;
}
if ( needsUpdate ) {
event.preventDefault();
scope.update();
}
}
function handleTouchStartRotate( event ) {
if ( event.touches.length == 1 ) {
rotateStart.set( event.touches[ 0 ].pageX, event.touches[ 0 ].pageY );
} else {
const x = 0.5 * ( event.touches[ 0 ].pageX + event.touches[ 1 ].pageX );
const y = 0.5 * ( event.touches[ 0 ].pageY + event.touches[ 1 ].pageY );
rotateStart.set( x, y );
}
}
function handleTouchStartPan( event ) {
if ( event.touches.length == 1 ) {
panStart.set( event.touches[ 0 ].pageX, event.touches[ 0 ].pageY );
} else {
const x = 0.5 * ( event.touches[ 0 ].pageX + event.touches[ 1 ].pageX );
const y = 0.5 * ( event.touches[ 0 ].pageY + event.touches[ 1 ].pageY );
panStart.set( x, y );
}
}
function handleTouchStartDolly( event ) {
const dx = event.touches[ 0 ].pageX - event.touches[ 1 ].pageX;
const dy = event.touches[ 0 ].pageY - event.touches[ 1 ].pageY;
const distance = Math.sqrt( dx * dx + dy * dy );
dollyStart.set( 0, distance );
}
function handleTouchStartDollyPan( event ) {
if ( scope.enableZoom ) handleTouchStartDolly( event );
if ( scope.enablePan ) handleTouchStartPan( event );
}
function handleTouchStartDollyRotate( event ) {
if ( scope.enableZoom ) handleTouchStartDolly( event );
if ( scope.enableRotate ) handleTouchStartRotate( event );
}
function handleTouchMoveRotate( event ) {
if ( event.touches.length == 1 ) {
rotateEnd.set( event.touches[ 0 ].pageX, event.touches[ 0 ].pageY );
} else {
const x = 0.5 * ( event.touches[ 0 ].pageX + event.touches[ 1 ].pageX );
const y = 0.5 * ( event.touches[ 0 ].pageY + event.touches[ 1 ].pageY );
rotateEnd.set( x, y );
}
rotateDelta.subVectors( rotateEnd, rotateStart ).multiplyScalar( scope.rotateSpeed );
const element = scope.domElement;
rotateLeft( 2 * Math.PI * rotateDelta.x / element.clientHeight );
rotateUp( 2 * Math.PI * rotateDelta.y / element.clientHeight );
rotateStart.copy( rotateEnd );
}
function handleTouchMovePan( event ) {
if ( event.touches.length == 1 ) {
panEnd.set( event.touches[ 0 ].pageX, event.touches[ 0 ].pageY );
} else {
const x = 0.5 * ( event.touches[ 0 ].pageX + event.touches[ 1 ].pageX );
const y = 0.5 * ( event.touches[ 0 ].pageY + event.touches[ 1 ].pageY );
panEnd.set( x, y );
}
panDelta.subVectors( panEnd, panStart ).multiplyScalar( scope.panSpeed );
pan( panDelta.x, panDelta.y );
panStart.copy( panEnd );
}
function handleTouchMoveDolly( event ) {
const dx = event.touches[ 0 ].pageX - event.touches[ 1 ].pageX;
const dy = event.touches[ 0 ].pageY - event.touches[ 1 ].pageY;
const distance = Math.sqrt( dx * dx + dy * dy );
dollyEnd.set( 0, distance );
dollyDelta.set( 0, Math.pow( dollyEnd.y / dollyStart.y, scope.zoomSpeed ) );
dollyOut( dollyDelta.y );
dollyStart.copy( dollyEnd );
}
function handleTouchMoveDollyPan( event ) {
if ( scope.enableZoom ) handleTouchMoveDolly( event );
if ( scope.enablePan ) handleTouchMovePan( event );
}
function handleTouchMoveDollyRotate( event ) {
if ( scope.enableZoom ) handleTouchMoveDolly( event );
if ( scope.enableRotate ) handleTouchMoveRotate( event );
}
function handleTouchEnd( ) {
}
function onPointerDown( event ) {
if ( scope.enabled === false ) return;
switch ( event.pointerType ) {
case 'mouse':
case 'pen':
onMouseDown( event );
break;
}
}
function onPointerMove( event ) {
if ( scope.enabled === false ) return;
switch ( event.pointerType ) {
case 'mouse':
case 'pen':
onMouseMove( event );
break;
}
}
function onPointerUp( event ) {
switch ( event.pointerType ) {
case 'mouse':
case 'pen':
onMouseUp( event );
break;
}
}
function onMouseDown( event ) {
event.preventDefault();
scope.domElement.focus ? scope.domElement.focus() : window.focus();
let mouseAction;
switch ( event.button ) {
case 0:
mouseAction = scope.mouseButtons.LEFT;
break;
case 1:
mouseAction = scope.mouseButtons.MIDDLE;
break;
case 2:
mouseAction = scope.mouseButtons.RIGHT;
break;
default:
mouseAction = - 1;
}
switch ( mouseAction ) {
case THREE.MOUSE.DOLLY:
if ( scope.enableZoom === false ) return;
handleMouseDownDolly( event );
state = STATE.DOLLY;
break;
case THREE.MOUSE.ROTATE:
if ( event.ctrlKey || event.metaKey || event.shiftKey ) {
if ( scope.enablePan === false ) return;
handleMouseDownPan( event );
state = STATE.PAN;
} else {
if ( scope.enableRotate === false ) return;
handleMouseDownRotate( event );
state = STATE.ROTATE;
}
break;
case THREE.MOUSE.PAN:
if ( event.ctrlKey || event.metaKey || event.shiftKey ) {
if ( scope.enableRotate === false ) return;
handleMouseDownRotate( event );
state = STATE.ROTATE;
} else {
if ( scope.enablePan === false ) return;
handleMouseDownPan( event );
state = STATE.PAN;
}
break;
default:
state = STATE.NONE;
}
if ( state !== STATE.NONE ) {
scope.domElement.ownerDocument.addEventListener( 'pointermove', onPointerMove );
scope.domElement.ownerDocument.addEventListener( 'pointerup', onPointerUp );
scope.dispatchEvent( _startEvent );
}
}
function onMouseMove( event ) {
if ( scope.enabled === false ) return;
event.preventDefault();
switch ( state ) {
case STATE.ROTATE:
if ( scope.enableRotate === false ) return;
handleMouseMoveRotate( event );
break;
case STATE.DOLLY:
if ( scope.enableZoom === false ) return;
handleMouseMoveDolly( event );
break;
case STATE.PAN:
if ( scope.enablePan === false ) return;
handleMouseMovePan( event );
break;
}
}
function onMouseUp( event ) {
scope.domElement.ownerDocument.removeEventListener( 'pointermove', onPointerMove );
scope.domElement.ownerDocument.removeEventListener( 'pointerup', onPointerUp );
if ( scope.enabled === false ) return;
handleMouseUp( event );
scope.dispatchEvent( _endEvent );
state = STATE.NONE;
}
function onMouseWheel( event ) {
if ( scope.enabled === false || scope.enableZoom === false || state !== STATE.NONE && state !== STATE.ROTATE ) return;
event.preventDefault();
scope.dispatchEvent( _startEvent );
handleMouseWheel( event );
scope.dispatchEvent( _endEvent );
}
function onKeyDown( event ) {
if ( scope.enabled === false || scope.enablePan === false ) return;
handleKeyDown( event );
}
function onTouchStart( event ) {
if ( scope.enabled === false ) return;
event.preventDefault();
switch ( event.touches.length ) {
case 1:
switch ( scope.touches.ONE ) {
case THREE.TOUCH.ROTATE:
if ( scope.enableRotate === false ) return;
handleTouchStartRotate( event );
state = STATE.TOUCH_ROTATE;
break;
case THREE.TOUCH.PAN:
if ( scope.enablePan === false ) return;
handleTouchStartPan( event );
state = STATE.TOUCH_PAN;
break;
default:
state = STATE.NONE;
}
break;
case 2:
switch ( scope.touches.TWO ) {
case THREE.TOUCH.DOLLY_PAN:
if ( scope.enableZoom === false && scope.enablePan === false ) return;
handleTouchStartDollyPan( event );
state = STATE.TOUCH_DOLLY_PAN;
break;
case THREE.TOUCH.DOLLY_ROTATE:
if ( scope.enableZoom === false && scope.enableRotate === false ) return;
handleTouchStartDollyRotate( event );
state = STATE.TOUCH_DOLLY_ROTATE;
break;
default:
state = STATE.NONE;
}
break;
default:
state = STATE.NONE;
}
if ( state !== STATE.NONE ) {
scope.dispatchEvent( _startEvent );
}
}
function onTouchMove( event ) {
if ( scope.enabled === false ) return;
event.preventDefault();
switch ( state ) {
case STATE.TOUCH_ROTATE:
if ( scope.enableRotate === false ) return;
handleTouchMoveRotate( event );
scope.update();
break;
case STATE.TOUCH_PAN:
if ( scope.enablePan === false ) return;
handleTouchMovePan( event );
scope.update();
break;
case STATE.TOUCH_DOLLY_PAN:
if ( scope.enableZoom === false && scope.enablePan === false ) return;
handleTouchMoveDollyPan( event );
scope.update();
break;
case STATE.TOUCH_DOLLY_ROTATE:
if ( scope.enableZoom === false && scope.enableRotate === false ) return;
handleTouchMoveDollyRotate( event );
scope.update();
break;
default:
state = STATE.NONE;
}
}
function onTouchEnd( event ) {
if ( scope.enabled === false ) return;
handleTouchEnd( event );
scope.dispatchEvent( _endEvent );
state = STATE.NONE;
}
function onContextMenu( event ) {
if ( scope.enabled === false ) return;
event.preventDefault();
}
scope.domElement.addEventListener( 'contextmenu', onContextMenu );
scope.domElement.addEventListener( 'pointerdown', onPointerDown );
scope.domElement.addEventListener( 'wheel', onMouseWheel, {
passive: false
} );
scope.domElement.addEventListener( 'touchstart', onTouchStart, {
passive: false
} );
scope.domElement.addEventListener( 'touchend', onTouchEnd );
scope.domElement.addEventListener( 'touchmove', onTouchMove, {
passive: false
} );
this.update();
}
}
class MapControls extends OrbitControls {
constructor( object, domElement ) {
super( object, domElement );
this.screenSpacePanning = false;
this.mouseButtons.LEFT = THREE.MOUSE.PAN;
this.mouseButtons.RIGHT = THREE.MOUSE.ROTATE;
this.touches.ONE = THREE.TOUCH.PAN;
this.touches.TWO = THREE.TOUCH.DOLLY_ROTATE;
}
}
THREE.MapControls = MapControls;
THREE.OrbitControls = OrbitControls;
} )();
  return true;
}
''';

