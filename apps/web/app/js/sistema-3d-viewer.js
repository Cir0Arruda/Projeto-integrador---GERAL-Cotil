/* ============================================================
   Sistema - Motor de Visualizacao 3D (CAD Style / Fusion 360)
   v2.0 - Suporte completo a texturas: OBJ+MTL, GLB embedded, STL vertex colors
   Carregamento autenticado via fetch() + parse() - bypassa XHR sem Authorization
   ============================================================ */

function disposeViewerResources(root) {
  if (!root) return;
  const geometries = new Set(), materials = new Set(), textures = new Set();
  root.traverse(object => {
    if (object.geometry) geometries.add(object.geometry);
    for (const material of (Array.isArray(object.material) ? object.material : object.material ? [object.material] : [])) {
      materials.add(material);
      for (const value of Object.values(material)) if (value?.isTexture) textures.add(value);
    }
    object.shadow?.map?.dispose();
    object.shadow?.mapPass?.dispose();
  });
  textures.forEach(texture => texture.dispose());
  geometries.forEach(geometry => geometry.dispose());
  materials.forEach(material => material.dispose());
}

function createViewerResourceManager() {
  const manager = new THREE.LoadingManager();
  // Uploaded scenes may reference their authenticated blobs or embedded resources,
  // never arbitrary remote URLs declared by an OBJ/MTL/GLTF file.
  manager.setURLModifier(resource => {
    const value = String(resource);
    if (/^data:(?:application\/(?:octet-stream|gltf-buffer)|image\/(?:png|jpeg|webp));base64,[A-Za-z0-9+/]+={0,2}$/i.test(value)) return value;
    try { const url = new URL(value); if (url.protocol === 'blob:' && url.origin === location.origin) return value; } catch (_) {}
    throw new Error('O modelo precisa usar texturas e recursos incorporados ou anexos associados.');
  });
  return manager;
}

class ASTHAViewer3D {
  constructor(containerId, isMini = false) {
    this.containerId = containerId;
    this.container = document.getElementById(containerId);
    this.isMini = isMini;
    this._blobUrls = []; // track blob URLs for cleanup

    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.controls = null;
    this.reqFrame = null;
    this.modelGroup = null;
    this.grid = null;
    this.active = false;
    this.disposed = false;
    this.loadGeneration = 0;

    this.init();
  }

  init() {
    if (!this.container) return;

    if (typeof THREE === 'undefined') {
      console.error('[ASTHAViewer3D] THREE.js nao esta carregado.');
      return;
    }

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xd7e2ec);
    this.scene.fog = new THREE.Fog(0xd7e2ec, 20, 2000);

    // Lighting (PBR)
    const hemiLight = new THREE.HemisphereLight(0xffffff, 0x52657a, 0.82);
    hemiLight.position.set(0, 200, 0);
    this.scene.add(hemiLight);

    const dirLight = new THREE.DirectionalLight(0xffffff, 1.05);
    dirLight.position.set(50, 100, 50);
    dirLight.castShadow = true;
    dirLight.shadow.camera.top = 100;
    dirLight.shadow.camera.bottom = -100;
    dirLight.shadow.camera.left = -100;
    dirLight.shadow.camera.right = 100;
    dirLight.shadow.mapSize.width = 2048;
    dirLight.shadow.mapSize.height = 2048;
    this.scene.add(dirLight);

    const fillLight = new THREE.DirectionalLight(0xc5dcf1, 0.58);
    fillLight.position.set(-50, 50, -50);
    this.scene.add(fillLight);

    // Floor Grid
    const gridColor = 0x8da4b8;
    this.grid = new THREE.GridHelper(2000, 100, gridColor, gridColor);
    this.grid.material.opacity = 0.18;
    this.grid.material.transparent = true;
    this.scene.add(this.grid);

    const floorMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(2000, 2000),
      new THREE.ShadowMaterial({ opacity: 0.15 })
    );
    floorMesh.rotation.x = -Math.PI / 2;
    floorMesh.receiveShadow = true;
    this.scene.add(floorMesh);

    // Camera
    const w = this.container.clientWidth || 400;
    const h = this.container.clientHeight || 300;
    this.camera = new THREE.PerspectiveCamera(40, w / h, 0.1, 5000);

    // Renderer
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    this.renderer.setSize(w, h);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    try {
      if (THREE.sRGBEncoding !== undefined) {
        this.renderer.outputEncoding = THREE.sRGBEncoding;
      } else if (THREE.SRGBColorSpace !== undefined) {
        this.renderer.outputColorSpace = THREE.SRGBColorSpace;
      }
    } catch(e) {}

    try {
      if (THREE.ACESFilmicToneMapping !== undefined) {
        this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
        this.renderer.toneMappingExposure = 1.0;
      }
    } catch(e) {}

    this.container.appendChild(this.renderer.domElement);

    const OrbitControlsCtor = THREE.OrbitControls;
    if (!OrbitControlsCtor) {
      console.error('[ASTHAViewer3D] OrbitControls nao encontrado.');
      return;
    }

    this.controls = new OrbitControlsCtor(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.08;
    this.controls.enablePan = true;
    this.onControlsChange = () => this.requestRender();
    this.controls.addEventListener('change', this.onControlsChange);

    if (this.isMini) {
      this.controls.autoRotate = true;
      this.controls.autoRotateSpeed = 1.0;
      this.controls.enableZoom = false;
    } else {
      this.controls.screenSpacePanning = true;
    }

    this.onResizeBinding = this.resize.bind(this);
    window.addEventListener('resize', this.onResizeBinding);
    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver(() => this.resize());
      this.resizeObserver.observe(this.container);
    }
    this.onVisibility = () => {
      if (document.hidden) this.cancelFrame(); else this.requestRender();
    };
    this.onPageHide = event => { if (event.persisted) this.cancelFrame(); else this.dispose(); };
    this.onPageShow = () => this.requestRender();
    document.addEventListener('visibilitychange', this.onVisibility);
    window.addEventListener('pagehide', this.onPageHide);
    window.addEventListener('pageshow', this.onPageShow);
  }

  resize() {
    if (!this.container || !this.camera || !this.renderer) return;
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    if (w === 0 || h === 0) return;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.requestRender();
  }

  renderLoop = () => {
    this.reqFrame = null;
    if (!this.active || this.disposed || document.hidden || !this.container?.getClientRects().length) return;
    if (this.controls) this.controls.update();
    if (this.renderer && this.scene && this.camera) {
      this.renderer.render(this.scene, this.camera);
    }
    if (this.controls?.autoRotate) this.requestRender();
  };

  requestRender() {
    if (!this.active || this.disposed || this.reqFrame !== null || document.hidden || !this.container?.getClientRects().length) return;
    this.reqFrame = requestAnimationFrame(this.renderLoop);
  }

  start() {
    if (!this.renderer || this.disposed) return;
    this.active = true;
    this.requestRender();
  }

  cancelFrame() {
    if (this.reqFrame !== null) {
      cancelAnimationFrame(this.reqFrame);
      this.reqFrame = null;
    }
  }

  stop() { this.active = false; this.cancelFrame(); }

  _revokeBlobUrls() {
    this._blobUrls.forEach(function(u) { try { URL.revokeObjectURL(u); } catch(e) {} });
    this._blobUrls = [];
  }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    this.loadGeneration++;
    this.loadController?.abort();
    this.stop();
    this._revokeBlobUrls();
    window.removeEventListener('resize', this.onResizeBinding);
    document.removeEventListener('visibilitychange', this.onVisibility);
    window.removeEventListener('pagehide', this.onPageHide);
    window.removeEventListener('pageshow', this.onPageShow);
    this.controls?.removeEventListener('change', this.onControlsChange);
    this.controls?.dispose();
    disposeViewerResources(this.scene);
    this.scene?.clear();
    this.modelGroup = null;
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
      this.resizeObserver = null;
    }
    if (this.renderer && this.renderer.domElement && this.container) {
      try { this.container.removeChild(this.renderer.domElement); } catch(e) {}
    }
    if (this.renderer) this.renderer.dispose();
  }

  // ----------------------------------------------------------------
  // finishSetup: Centers, scales, positions camera, starts render
  // ----------------------------------------------------------------
  _finishSetup(object, ext, onComplete, generation = this.loadGeneration) {
    if (this.disposed || generation !== this.loadGeneration || this.loadStillCurrent && !this.loadStillCurrent()) { disposeViewerResources(object); return; }
    const self = this;
    object.traverse(function(child) {
      if (child.isMesh) {
        child.castShadow = true;
        child.receiveShadow = true;
        // Only override material for STL/OBJ without textures
        const extLwr = (ext || '').toLowerCase();
        if (extLwr === 'stl') {
          // Check for vertex colors from binary STL
          const geo = child.geometry;
          if (geo && geo.attributes && geo.attributes.color) {
            child.material = new THREE.MeshStandardMaterial({
              vertexColors: true,
              metalness: 0.3,
              roughness: 0.5
            });
          } else {
            child.material = new THREE.MeshStandardMaterial({
              color: 0x90949a,
              metalness: 0.5,
              roughness: 0.3
            });
          }
        } else if (extLwr === 'obj') {
          // Keep material from MTL if present, otherwise apply default
          if (!child.material || child.material.name === '' || child.material.type === 'MeshBasicMaterial') {
            child.material = new THREE.MeshStandardMaterial({
              color: 0x90949a,
              metalness: 0.3,
              roughness: 0.5
            });
          } else {
            // Upgrade MeshPhongMaterial (from MTL) to MeshStandardMaterial for PBR lighting
            if (child.material.isMeshPhongMaterial) {
              const oldMat = child.material;
              const newMat = new THREE.MeshStandardMaterial({
                color: oldMat.color,
                map: oldMat.map,
                normalMap: oldMat.normalMap,
                roughness: 0.6,
                metalness: 0.1,
                transparent: oldMat.transparent,
                opacity: oldMat.opacity
              });
              child.material = newMat;
            }
          }
        }
        // GLTF/GLB: keep original PBR materials untouched
      }
    });

    self.modelGroup.add(object);

    const box = new THREE.Box3().setFromObject(self.modelGroup);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());

    self.modelGroup.position.x -= center.x;
    self.modelGroup.position.y -= box.min.y;
    self.modelGroup.position.z -= center.z;

    const maxDim = Math.max(size.x, size.y, size.z) || 1;
    const fov = self.camera.fov * (Math.PI / 180);
    var cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2)) * 2.0;

    self.camera.position.set(cameraZ * 0.7, maxDim * 1.2, cameraZ * 0.9);
    self.camera.lookAt(0, maxDim / 2, 0);
    self.controls.target.set(0, maxDim / 2, 0);
    self.controls.update();

    self.start();
    if (onComplete) onComplete();
  }

  _showError(message) {
    console.error('[ASTHAViewer3D]', message);
    if (!this.container) return;
    this.container.style.position = 'relative';
    var old = this.container.querySelector('.ev3d-error');
    if (old) old.remove();
    var errDiv = document.createElement('div');
    errDiv.className = 'ev3d-error';
    errDiv.style.cssText = 'position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);color:#FF4757;font-size:13px;font-weight:600;text-align:center;font-family:Inter,sans-serif;z-index:10;pointer-events:none;padding:16px;line-height:1.6;';
    errDiv.textContent = '⚠️ Erro ao carregar modelo';
    const detail = document.createElement('span');
    detail.style.cssText = 'display:block;font-weight:400;font-size:11px;color:#999;';
    detail.textContent = String(message || '');
    errDiv.appendChild(detail);
    this.container.appendChild(errDiv);
  }

  // ----------------------------------------------------------------
  // loadModel - main entry point
  // filesContext = { code: 'MERB-xxx', files: [...] } â€” optional,
  // used to find associated MTL + texture files for OBJ models.
  // ----------------------------------------------------------------
  loadModel(url, ext, onComplete, onError, filesContext) {
    if (this.disposed) return;
    if (!this.scene || !this.camera || !this.controls) {
      var msg = 'Viewer nao inicializado';
      this._showError(msg);
      if (onError) onError(new Error(msg));
      return;
    }

    const generation = ++this.loadGeneration;
    this.loadController?.abort();
    this.loadController = new AbortController();
    const signal = this.loadController.signal;
    if (this.modelGroup) {
      disposeViewerResources(this.modelGroup);
      this.scene.remove(this.modelGroup);
      this.modelGroup = null;
    }
    this._revokeBlobUrls(); // free old texture blobs

    this.modelGroup = new THREE.Group();
    this.scene.add(this.modelGroup);

    var self = this;
    var extLower = (ext || '').toLowerCase();
    function failed(err) {
      if (!stillCurrent()) return;
      self._showError(err.message);
      if (onError) onError(err);
    }

    // Auth token for all fetch calls
    var token = (typeof localStorage !== 'undefined') ? localStorage.getItem('astha_token') : null;
    var fetchHeaders = token ? { 'Authorization': 'Bearer ' + token } : {};
    var baseApi = (typeof API !== 'undefined') ? API.BASE_URL : '/api';
    const stillCurrent = () => !self.disposed && generation === self.loadGeneration &&
      localStorage.getItem('astha_token') === token &&
      ((typeof API !== 'undefined') ? API.BASE_URL : '/api') === baseApi;
    this.loadStillCurrent = stillCurrent;

    function authFetch(fetchUrl) {
      let target;
      try {
        target = new URL(fetchUrl, location.href);
        const apiOrigin = new URL(baseApi, location.href).origin;
        if (target.username || target.password ||
            !(['http:', 'https:'].includes(target.protocol) && target.origin === apiOrigin) &&
            !(target.protocol === 'blob:' && target.origin === location.origin)) throw new Error();
      } catch (_) {
        return Promise.reject(new Error('Origem do arquivo 3D não autorizada.'));
      }
      const headers = target.protocol === 'blob:' ? {} : fetchHeaders;
      return fetch(fetchUrl, { headers, signal, redirect: 'error' }).then(async function(res) {
        if (!stillCurrent()) throw new DOMException('Carregamento cancelado', 'AbortError');
        if (!res.ok) throw new Error('HTTP ' + res.status + ' em ' + fetchUrl);
        const buffer = await res.arrayBuffer();
        if (!stillCurrent()) throw new DOMException('Carregamento cancelado', 'AbortError');
        return buffer;
      });
    }

    // â”€â”€ STL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if (['step', 'stp', 'iges', 'igs'].indexOf(extLower) !== -1) {
      authFetch(url)
        .then(function(buffer) {
          if (!window.EamCadImport) throw new Error('Importador CAD indisponível');
          return window.EamCadImport.parse(buffer, extLower);
        })
        .then(function(group) { self._finishSetup(group, 'gltf', onComplete, generation); })
        .catch(failed);
    } else if (extLower === 'stl') {
      authFetch(url)
        .then(function(buffer) {
          if (!THREE.STLLoader) throw new Error('STLLoader indisponivel');
          var geometry = new THREE.STLLoader().parse(buffer);
          self._finishSetup(new THREE.Mesh(geometry), 'stl', onComplete, generation);
        })
        .catch(failed);

    // â”€â”€ OBJ + MTL + Textures â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    } else if (extLower === 'obj') {
      authFetch(url)
        .then(function(objBuffer) {
          var objText = new TextDecoder().decode(objBuffer);
          var allFiles = (filesContext && filesContext.files) ? filesContext.files : [];
          var matCode = (filesContext && filesContext.code) ? filesContext.code : '';

          // Look for an associated MTL file in the same material's files list
          var mtlFile = allFiles.find(function(f) { return f.filename.match(/\.mtl$/i); });

          if (mtlFile && THREE.MTLLoader && THREE.OBJLoader) {
            var mtlUrl = baseApi + '/materials/' + encodeURIComponent(matCode) + '/files/' + encodeURIComponent(mtlFile.id) + '/data';
            return authFetch(mtlUrl).then(function(mtlBuffer) {
              var mtlText = new TextDecoder().decode(mtlBuffer);

              // Find all texture filename references inside the MTL
              var texPattern = /^(?:map_[A-Za-z_]+|bump|disp|refl|norm)\s+(.+)$/gm;
              var referencedTextures = [];
              var m;
              while ((m = texPattern.exec(mtlText)) !== null) {
                var rawPath = m[1].trim();
                var baseName = rawPath.split(/[/\\]/).pop();
                if (referencedTextures.indexOf(baseName) === -1) {
                  referencedTextures.push(baseName);
                }
              }

              // Fetch each referenced texture and create an authenticated Blob URL
              var texBlobMap = {};
              var texFetches = referencedTextures.map(function(texName) {
                var texFile = allFiles.find(function(f) {
                  return f.filename.toLowerCase() === texName.toLowerCase();
                });
                if (!texFile) return Promise.resolve();
                var texUrl = baseApi + '/materials/' + encodeURIComponent(matCode) + '/files/' + encodeURIComponent(texFile.id) + '/data';
                return authFetch(texUrl).then(function(texBuffer) {
                  var mimeType = texFile.mime_type || 'image/png';
                  var blob = new Blob([texBuffer], { type: mimeType });
                  var blobUrl = URL.createObjectURL(blob);
                  self._blobUrls.push(blobUrl); // track for cleanup
                  texBlobMap[texName.toLowerCase()] = blobUrl;
                }).catch(function(e) {
                  console.warn('[ASTHAViewer3D] Textura nao encontrada:', texName, e.message);
                });
              });

              return Promise.all(texFetches).then(function() {
                // Patch MTL text: replace texture filenames with blob URLs
                var patchedMtl = mtlText.replace(
                  /^((?:map_[A-Za-z_]+|bump|disp|refl|norm)\s+)(.+)$/gm,
                  function(line, prop, rawPath) {
                    var baseName = rawPath.trim().split(/[/\\]/).pop().toLowerCase();
                    var blobUrl = texBlobMap[baseName];
                    return blobUrl ? (prop + blobUrl) : line;
                  }
                );

                // Parse MTL then OBJ
                var resourceManager = createViewerResourceManager();
                var mtlLoader = new THREE.MTLLoader(resourceManager);
                var materials = mtlLoader.parse(patchedMtl, '');
                materials.preload();
                var objLoader = new THREE.OBJLoader(resourceManager);
                objLoader.setMaterials(materials);
                return objLoader.parse(objText);
              });
            });
          } else {
            // OBJ without MTL - plain parse
            if (!THREE.OBJLoader) throw new Error('OBJLoader indisponivel');
            return Promise.resolve(new THREE.OBJLoader().parse(objText));
          }
        })
        .then(function(object) {
          self._finishSetup(object, 'obj', onComplete, generation);
        })
        .catch(failed);

    // â”€â”€ GLTF / GLB (textures embedded in binary) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    } else if (extLower === 'gltf' || extLower === 'glb') {
      authFetch(url)
        .then(function(buffer) {
          if (!THREE.GLTFLoader) throw new Error('GLTFLoader indisponivel');

          // For GLB, textures are embedded â€” parse works out of the box.
          // For GLTF (text) with external textures, we build a resource map
          // from the material's file list so external references resolve.
          function doGltfParse() {
            if (self.disposed || generation !== self.loadGeneration) return Promise.resolve();
            return new Promise(function(resolve, reject) {
              new THREE.GLTFLoader(createViewerResourceManager()).parse(buffer, '', function(gltf) {
                self._finishSetup(gltf.scene, extLower, onComplete, generation);
                resolve();
              }, reject);
            });
          }

          // GLTF uploads are self-contained; unrelated image attachments must not
          // be downloaded on every model view.
          return doGltfParse();
        })
        .catch(failed);

    } else {
      var unsupportedMsg = 'Formato nao suportado: ' + ext;
      this._showError(unsupportedMsg);
      if (onError) onError(new Error(unsupportedMsg));
    }
  }
}

// â”€â”€ Globals for integration â”€â”€
let miniViewerInst = null;
let fullViewerInst = null;
let miniViewerTimer = null;
let fullViewerTimer = null;

function setupInfoMediaGallery(fileId, fileCode, filename, fileExt, imageUrl, filesContext) {
  clearTimeout(miniViewerTimer);
  const gallery = document.getElementById('eoMediaGallery');
  const imgEl = document.getElementById('eoMediaImage');
  const canvasEl = document.getElementById('eoMediaCanvas');
  const loadingEl = document.getElementById('eoMediaLoading');
  const toggleBtn = document.getElementById('eoMediaToggleBtn');
  const fullscreenBtn = document.querySelector('[data-info-fullscreen]');
  if (fullscreenBtn) fullscreenBtn.hidden = !fileId;
  const mediaControls = gallery?.querySelector('.material-media-controls');
  if (mediaControls) mediaControls.hidden = !fileId;
  gallery?.classList.toggle('is-empty', !fileId && !imageUrl);

  if (miniViewerInst) {
    miniViewerInst.dispose();
    miniViewerInst = null;
  }

  if (canvasEl) canvasEl.style.display = 'none';
  if (loadingEl) loadingEl.style.display = 'none';

  if (!fileId) {
    if (toggleBtn) toggleBtn.style.display = 'none';
    if (imgEl) {
      imgEl.style.display = 'block';
      imgEl.src = imageUrl || '';
    }
    if (!imageUrl && imgEl) {
      imgEl.style.display = 'flex';
      imgEl.textContent = 'Nenhuma imagem ou modelo 3D anexado.';
      imgEl.style.alignItems = 'center';
      imgEl.style.justifyContent = 'center';
    }
    return;
  }

  if (toggleBtn) toggleBtn.style.display = imageUrl ? 'flex' : 'none';
  if (imgEl) imgEl.style.display = 'none';
  if (canvasEl) canvasEl.style.display = 'block';
  if (loadingEl) loadingEl.style.display = 'flex';

  if (canvasEl) {
    canvasEl.setAttribute('data-file-id', fileId);
    canvasEl.setAttribute('data-file-code', fileCode);
    canvasEl.setAttribute('data-file-name', filename);
    canvasEl.setAttribute('data-file-ext', fileExt);
    canvasEl.setAttribute('data-files-ctx', JSON.stringify(filesContext || {}));
  }

  const baseUrl = (typeof API !== 'undefined') ? API.BASE_URL : '/api';
  const url = baseUrl + '/materials/' + encodeURIComponent(fileCode) + '/files/' + encodeURIComponent(fileId) + '/data';

  miniViewerTimer = setTimeout(function() {
    miniViewerTimer = null;
    if (!canvasEl?.isConnected || document.getElementById('eoMediaCanvas') !== canvasEl || !document.getElementById('moreInfoModal')?.classList.contains('active')) return;
    try {
      miniViewerInst = new ASTHAViewer3D('eoMediaCanvas', true);
      miniViewerInst.loadModel(url, fileExt, function() {
        if (loadingEl) loadingEl.style.display = 'none';
      }, function() {
        if (loadingEl) loadingEl.style.display = 'none';
        if (typeof showToast === 'function') showToast('Erro ao renderizar modelo 3D', 'error');
      }, filesContext);
    } catch(e) {
      console.error('[setupInfoMediaGallery] Erro:', e);
      if (loadingEl) loadingEl.style.display = 'none';
    }
  }, 80);
}

function toggleInfoMedia() {
  const imgEl = document.getElementById('eoMediaImage');
  const canvasEl = document.getElementById('eoMediaCanvas');
  if (!imgEl || !canvasEl) return;
  if (imgEl.style.display === 'none') {
    imgEl.style.display = 'block';
    canvasEl.style.display = 'none';
    if (miniViewerInst) miniViewerInst.stop();
  } else {
    imgEl.style.display = 'none';
    canvasEl.style.display = 'block';
    if (miniViewerInst) {
      miniViewerInst.resize();
      miniViewerInst.start();
    }
  }
}

function expandMiniViewer() {
  const canvasEl = document.getElementById('eoMediaCanvas');
  if (!canvasEl) return;
  const fid = canvasEl.getAttribute('data-file-id');
  const fcode = canvasEl.getAttribute('data-file-code');
  const fname = canvasEl.getAttribute('data-file-name');
  const fext = canvasEl.getAttribute('data-file-ext');
  const fctxRaw = canvasEl.getAttribute('data-files-ctx');
  if (!fid) return;

  let filesContext = {};
  try { filesContext = JSON.parse(fctxRaw || '{}'); } catch(e) {}

  const baseUrl = (typeof API !== 'undefined') ? API.BASE_URL : '/api';
  const url = baseUrl + '/materials/' + encodeURIComponent(fcode) + '/files/' + encodeURIComponent(fid) + '/data';
  open3DViewer(url, fext, fname, filesContext);
}

// Fullscreen Viewer
function open3DViewer(url, ext, title, filesContext) {
  clearTimeout(fullViewerTimer);
  const modal = document.getElementById('viewer3DModal');
  const titleEl = document.getElementById('viewer3DTitle');
  const loadingEl = document.getElementById('viewer3DLoading');
  const containerEl = document.getElementById('viewer3DContainer');

  if (!modal || !containerEl) return;

  if (titleEl) titleEl.textContent = 'Visualizador CAD: ' + (title || '');
  modal.classList.add('active');
  if (loadingEl) loadingEl.style.display = 'block';

  if (fullViewerInst) {
    fullViewerInst.dispose();
    fullViewerInst = null;
  }

  fullViewerTimer = setTimeout(function() {
    fullViewerTimer = null;
    if (!modal.isConnected || !modal.classList.contains('active') || !containerEl.isConnected) return;
    try {
      fullViewerInst = new ASTHAViewer3D('viewer3DContainer', false);
      fullViewerInst.loadModel(url, ext, function() {
        if (loadingEl) loadingEl.style.display = 'none';
      }, function(err) {
        if (loadingEl) loadingEl.textContent = 'Erro ao carregar modelo 3D: ' + ((err && err.message) || '');
      }, filesContext || null);
    } catch(e) {
      console.error('[open3DViewer] Erro:', e);
      if (loadingEl) loadingEl.textContent = 'Erro ao inicializar visualizador 3D.';
    }
  }, 150);
}

function close3DViewer() {
  clearTimeout(fullViewerTimer);
  fullViewerTimer = null;
  const modal = document.getElementById('viewer3DModal');
  if (modal) modal.classList.remove('active');
  if (fullViewerInst) {
    fullViewerInst.dispose();
    fullViewerInst = null;
  }
}

