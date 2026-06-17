/* MangoCMS — Collection-flow controller.
   Handles: Create-Collection wizard · Manage-Fields side panel ·
   Choose-Field-Type · Add-a-Field (Settings/Validations/Default value)
   Layout/placement is borrowed from the Wix Studio CMS flow; visuals
   are pure MangoCMS (Inter + Familjen Grotesk + mist/mango). */
(function () {

  // ─────────────────────────────────────────────────────────────
  //  ICON SET — small inline SVGs, sized 22×22
  // ─────────────────────────────────────────────────────────────
  const S = (p, w) => `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w||1.8}" stroke-linecap="round" stroke-linejoin="round">${p}</svg>`;
  const I = {
    text:    S('<path d="M4 7V5h16v2M9 19h6M12 5v14"/>'),
    rich:    S('<path d="M4 7V5h16v2M9 19h6M12 5v14"/><path d="M5 11h6M5 14h4"/>'),
    richc:   S('<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M7 9h6M7 12h10M7 15h8"/>'),
    url:     S('<path d="M10 13a5 5 0 0 0 7.5.5L21 10a5 5 0 0 0-7-7l-2 2"/><path d="M14 11a5 5 0 0 0-7.5-.5L3 14a5 5 0 0 0 7 7l2-2"/>'),
    email:   S('<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 7 9-7"/>'),
    number:  S('<path d="M5 9h14M5 15h14M10 4l-2 16M16 4l-2 16"/>'),
    bool:    S('<rect x="3" y="5" width="18" height="14" rx="7"/><circle cx="16" cy="12" r="4" fill="currentColor"/>'),
    color:   S('<path d="M12 3c4 5 6 8 6 11a6 6 0 1 1-12 0c0-3 2-6 6-11z"/>'),
    ref:     S('<rect x="3" y="9" width="8" height="6" rx="2"/><rect x="13" y="9" width="8" height="6" rx="2"/><path d="M11 12h2"/>'),
    mref:    S('<rect x="2" y="7" width="7" height="5" rx="1.5"/><rect x="2" y="14" width="7" height="5" rx="1.5"/><rect x="13" y="10.5" width="9" height="5" rx="1.5"/><path d="M9 10h4M9 17h4"/>'),
    tags:    S('<path d="M21 12 13 4H4v9l8 8z"/><circle cx="8" cy="8" r="1.4" fill="currentColor"/>'),
    cat:     S('<path d="M6 4l3 5H3z"/><circle cx="17" cy="6.5" r="3"/><rect x="4" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>'),
    image:   S('<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.5"/><path d="m21 16-5-5L5 20"/>'),
    gallery: S('<rect x="6" y="6" width="14" height="14" rx="2"/><rect x="3" y="3" width="14" height="14" rx="2" fill="var(--mc-surface)"/>'),
    video:   S('<rect x="3" y="6" width="14" height="12" rx="2"/><path d="m17 10 5-3v10l-5-3z"/>'),
    audio:   S('<path d="M9 18V6l12-2v12"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>'),
    doc:     S('<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><polyline points="14 3 14 9 20 9"/><path d="M8 13h6M8 17h4"/>'),
    docs:    S('<path d="M15 5H9a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V11z"/><polyline points="15 5 15 11 21 11"/><path d="M3 17V5a2 2 0 0 1 2-2h8"/>'),
    asset:   S('<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>'),
    date:    S('<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>'),
    time:    S('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
    addr:    S('<path d="M12 21s-7-6.5-7-12a7 7 0 0 1 14 0c0 5.5-7 12-7 12z"/><circle cx="12" cy="9" r="2.5"/>'),
    obj:     S('<path d="M9 4H6a2 2 0 0 0-2 2v4a2 2 0 0 1-2 2 2 2 0 0 1 2 2v4a2 2 0 0 0 2 2h3"/><path d="M15 4h3a2 2 0 0 1 2 2v4a2 2 0 0 0 2 2 2 2 0 0 0-2 2v4a2 2 0 0 1-2 2h-3"/>'),
    arr:     S('<path d="M7 4H4v16h3M17 4h3v16h-3"/>'),
    // ui
    plus:    '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>',
    x:       '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    chev:    '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>',
    cbk:     '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>',
    grip:    '<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><circle cx="9" cy="5" r="1.6"/><circle cx="9" cy="12" r="1.6"/><circle cx="9" cy="19" r="1.6"/><circle cx="15" cy="5" r="1.6"/><circle cx="15" cy="12" r="1.6"/><circle cx="15" cy="19" r="1.6"/></svg>',
    info:    '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/></svg>',
  };

  // ─────────────────────────────────────────────────────────────
  //  FIELD-TYPE CONFIG
  // ─────────────────────────────────────────────────────────────
  const GROUPS = [
    { id: 'essentials', label: 'Essentials' },
    { id: 'orgRef',     label: 'Organization & Reference' },
    { id: 'media',      label: 'Media' },
    { id: 'time',       label: 'Time and location' },
    { id: 'js',         label: 'JavaScript (Velo code)' },
  ];

  // val = list of validation keys; def = supports default-value tab
  const TYPES = [
    { id:'text',   group:'essentials', label:'Text',          desc:'Titles, paragraph',                icon:'text',    val:['required','minLength','maxLength','pattern'], def:true },
    { id:'rich',   group:'essentials', label:'Rich text',     desc:'Text with formatting',              icon:'rich',    val:['required'],                                   def:false, defNote:'"Rich Text"' },
    { id:'richc',  group:'essentials', label:'Rich content',  desc:'Text with links and media',         icon:'richc',   val:['required'],                                   def:true },
    { id:'url',    group:'essentials', label:'URL',           desc:'Links',                             icon:'url',     val:['required','validUrl'],                        def:true },
    { id:'email',  group:'essentials', label:'Email',         desc:'Email addresses',                   icon:'email',   val:['required','validEmail'],                      def:true },
    { id:'number', group:'essentials', label:'Number',        desc:'ID, rating, order number',          icon:'number',  val:['required','minValue','maxValue','decimals'],  def:true },
    { id:'bool',   group:'essentials', label:'Boolean',       desc:'Yes or no, true or false',          icon:'bool',    val:['required'],                                   def:true },
    { id:'color',  group:'essentials', label:'Color',         desc:'Pick a HEX color',                  icon:'color',   val:['required'],                                   def:true },

    { id:'ref',    group:'orgRef',     label:'Reference',     desc:'Link to another collection',        icon:'ref',     val:['required'],                                   def:false, defNote:'"Reference"', extras:['refCollection'] },
    { id:'mref',   group:'orgRef',     label:'Multi-reference',desc:'Link to multiple items in another collection', icon:'mref', val:['required','minItems','maxItems'],   def:false, defNote:'"Multi-reference"', extras:['refCollection'] },
    { id:'tags',   group:'orgRef',     label:'Tags',          desc:'Tagging items, filters',            icon:'tags',    val:['required','minTags','maxTags'],               def:true },
    { id:'cat',    group:'orgRef',     label:'Category',      desc:'Assign categories to items, add category pages', icon:'cat', val:['required'],                          def:false, defNote:'"Category"', extras:['catCollection'] },

    { id:'image',  group:'media',      label:'Image',         desc:'Upload a single image',             icon:'image',   val:['required','maxFileSize','maxDimensions'],     def:true },
    { id:'gallery',group:'media',      label:'Media gallery', desc:'Upload multiple images or videos',  icon:'gallery', val:['required','minItems','maxItems'],             def:false, defNote:'"Media gallery"' },
    { id:'video',  group:'media',      label:'Video',         desc:'Upload a single video',             icon:'video',   val:['required','maxFileSize'],                     def:true },
    { id:'audio',  group:'media',      label:'Audio',         desc:'Upload an audio file',              icon:'audio',   val:['required','maxFileSize'],                     def:true },
    { id:'doc',    group:'media',      label:'Document',      desc:'Add files to a collection',         icon:'doc',     val:['required','maxFileSize','allowedTypes'],      def:false, defNote:'"Document"' },
    { id:'docs',   group:'media',      label:'Multiple documents', desc:'Upload files, let visitors upload to collection', icon:'docs', val:['required','minItems','maxItems','maxFileSize'], def:false, defNote:'"Multiple documents"' },
    { id:'asset',  group:'media',      label:'Digital asset', desc:'Upload a secure file to sell it on your site', icon:'asset', val:['required','maxFileSize'],          def:false, defNote:'"Digital asset"' },

    { id:'date',   group:'time',       label:'Date',          desc:'Date of event, date added',         icon:'date',    val:['required','earliestDate','latestDate'],       def:true },
    { id:'time',   group:'time',       label:'Time',          desc:'Opening hours',                     icon:'time',    val:['required','earliestTime','latestTime'],       def:false, defNote:'"Time"' },
    { id:'addr',   group:'time',       label:'Address',       desc:'Location',                          icon:'addr',    val:['required'],                                   def:true },

    { id:'obj',    group:'js',         label:'Object',        desc:'JavaScript object',                 icon:'obj',     val:['required'],                                   def:true },
    { id:'arr',    group:'js',         label:'Array',         desc:'JavaScript array',                  icon:'arr',     val:['required','minItems','maxItems'],             def:true },
  ];

  const VAL = {
    required:      { label:'Make this a required field', help:"Items can't be saved without this field filled in.", kind:'toggle' },
    minLength:     { label:'Minimum character count', kind:'number', placeholder:'0' },
    maxLength:     { label:'Maximum character count', kind:'number', placeholder:'255' },
    pattern:       { label:'Match a specific pattern (regex)', kind:'text', placeholder:'^[A-Za-z0-9_-]+$' },
    validUrl:      { label:'Must be a valid URL', kind:'toggle' },
    validEmail:    { label:'Must be a valid email address', kind:'toggle' },
    minValue:      { label:'Minimum value', kind:'number' },
    maxValue:      { label:'Maximum value', kind:'number' },
    decimals:      { label:'Decimal places allowed', kind:'number', placeholder:'2' },
    minItems:      { label:'Minimum number of items', kind:'number' },
    maxItems:      { label:'Maximum number of items', kind:'number' },
    minTags:       { label:'Minimum number of tags', kind:'number' },
    maxTags:       { label:'Maximum number of tags', kind:'number' },
    maxFileSize:   { label:'Maximum file size', kind:'unit', units:['KB','MB','GB'], defaultUnit:'MB', placeholder:'10' },
    allowedTypes:  { label:'Allowed file types', help:'Comma-separated extensions, e.g. pdf, docx, txt', kind:'text', placeholder:'pdf, docx, txt' },
    maxDimensions: { label:'Maximum dimensions', help:'Width × height in pixels', kind:'wh' },
    earliestDate:  { label:'Earliest allowed date', kind:'date' },
    latestDate:    { label:'Latest allowed date', kind:'date' },
    earliestTime:  { label:'Earliest allowed time', kind:'time' },
    latestTime:    { label:'Latest allowed time', kind:'time' },
  };

  // ─────────────────────────────────────────────────────────────
  //  STATE
  // ─────────────────────────────────────────────────────────────
  const W = { step:'type', collType:'content', startMode:'scratch', collName:'', collId:'', multi:true, suggested:{name:true, price:true, image:true, description:true, digitalFile:false} };
  const F = { open:false, type:'text', tab:'settings', name:'Field name', id:'fieldName', help:'', change:false, vals:{required:false} };
  const P = { open:false }; // manage fields panel

  // ─────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────
  function $(sel) { return document.querySelector(sel); }
  function html(strings, ...vals) {
    return strings.reduce((s, str, i) => s + str + (vals[i] == null ? '' : vals[i]), '');
  }
  function slugify(s) {
    return (s || '').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'');
  }
  function camelize(s) {
    const parts = (s || '').replace(/[^A-Za-z0-9]+/g, ' ').trim().split(' ');
    if (!parts.length) return '';
    return parts[0].toLowerCase() + parts.slice(1).map(p => p[0]?.toUpperCase() + p.slice(1).toLowerCase()).join('');
  }
  function findType(id) { return TYPES.find(t => t.id === id); }

  // ─────────────────────────────────────────────────────────────
  //  WIZARD: Create Collection
  // ─────────────────────────────────────────────────────────────
  function openWizard() {
    Object.assign(W, { step:'type', collType:'content', startMode:'scratch', collName:'', collId:'', multi:true });
    renderWizard();
    show('cf-wizard');
  }

  function renderWizard() {
    const root = $('#cf-wizard');
    root.innerHTML = `
      <div class="mc-modal cf-modal">
        <div class="mc-modal-head">
          <div>
            <div class="font-display font-bold text-lg">${wizardTitle()}</div>
            <div class="text-xs mt-0.5" style="color: var(--mc-text-3);">${wizardSubtitle()}</div>
            ${wizardSteps()}
          </div>
          <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-cf-close>${I.x}</button>
        </div>
        <div class="mc-modal-body">${wizardBody()}</div>
        <div class="mc-modal-foot">${wizardFoot()}</div>
      </div>`;
    bindWizard();
  }

  function wizardTitle() {
    if (W.step === 'category') return 'Create category collection';
    return 'Create a collection';
  }
  function wizardSubtitle() {
    if (W.step === 'catalog')  return 'Store and manage content that you wish to sell.';
    if (W.step === 'category') return 'Categories group items together and generate dynamic category pages.';
    return 'Store and manage content to use anywhere on your site.';
  }
  function wizardSteps() {
    const flow = W.collType === 'content'
      ? [{ id:'type', n:'1', l:'Type' }, { id:'contentStart', n:'2', l:'Method' }, { id:'contentName', n:'3', l:'Details' }]
      : W.collType === 'catalog'
        ? [{ id:'type', n:'1', l:'Type' }, { id:'catalog', n:'2', l:'Details' }]
        : [{ id:'type', n:'1', l:'Type' }, { id:'category', n:'2', l:'Details' }];
    const idx = flow.findIndex(s => s.id === W.step);
    return `<div class="cf-steps">${flow.map((s, i) => `
      <div class="cf-step ${i < idx ? 'done' : ''} ${i === idx ? 'active' : ''}">
        <span class="cf-step-dot">${i < idx ? '✓' : s.n}</span>
        <span>${s.l}</span>
      </div>${i < flow.length - 1 ? '<div class="cf-step-sep"></div>' : ''}`).join('')}</div>`;
  }

  function wizardBody() {
    if (W.step === 'type')         return wzType();
    if (W.step === 'contentStart') return wzContentStart();
    if (W.step === 'contentName')  return wzContentName();
    if (W.step === 'catalog')      return wzCatalog();
    if (W.step === 'category')     return wzCategory();
    return '';
  }

  function wzType() {
    const opt = (id, ico, t, d) => `
      <div class="cf-type ${W.collType === id ? 'selected' : ''}" data-coll-type="${id}">
        <div class="cf-radio"></div>
        <div class="cf-type-icon t-${id}">${I[ico]}</div>
        <div class="cf-type-body">
          <div class="cf-type-title">${t}</div>
          <div class="cf-type-desc">${d}</div>
        </div>
      </div>`;
    return `
      <div class="cf-eyebrow mb-3">What type of collection do you want to add?</div>
      <div class="cf-type-list">
        ${opt('content',  'richc', 'Content collection',  'For any managed content to use anywhere on your site.')}
        ${opt('catalog',  'asset', 'Catalog collection',  'For selling items directly from your site with cart and checkout pages.')}
        ${opt('category', 'cat',   'Category collection', 'For grouping content and generating dynamic category pages.')}
      </div>`;
  }

  function wzContentStart() {
    const card = (id, ico, t, d) => `
      <div class="cf-start ${W.startMode === id ? 'selected' : ''}" data-start-mode="${id}">
        <div class="cf-start-ico">${ico}</div>
        <div class="cf-start-title">${t}</div>
        <div class="cf-start-desc">${d}</div>
      </div>`;
    const sparkle = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/><circle cx="12" cy="12" r="3"/></svg>';
    const blank   = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M9 9h6M9 13h6M9 17h3"/></svg>';
    const csv     = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><polyline points="14 3 14 9 20 9"/><path d="M12 18v-6M9 15l3-3 3 3"/></svg>';
    return `
      <div class="cf-eyebrow mb-3">How do you want to start creating your collection?</div>
      <div class="cf-start-grid">
        ${card('ai',      sparkle, 'Create with AI',     'Set up collection fields and add some sample content with the help of AI.')}
        ${card('scratch', blank,   'Start from scratch', 'Manually add fields and content to your collection.')}
        ${card('csv',     csv,     'Import from CSV',    'Add content and fields from an existing CSV file to a new collection.')}
      </div>`;
  }

  function wzContentName() {
    return `
      <div class="grid grid-cols-1 gap-4">
        <div>
          <label class="mc-label">What's the name of your collection?</label>
          <input class="mc-input" id="cf-coll-name" placeholder="e.g., Team Members" value="${W.collName || ''}"/>
        </div>
        <div>
          <label class="mc-label">Set a collection ID to use in your code</label>
          <input class="mc-input font-mono" id="cf-coll-id" placeholder="e.g., teamMembers" value="${W.collId || ''}" style="background: var(--mc-surface-2);"/>
        </div>
      </div>
      <div class="mc-divider mt-5 mb-5"></div>
      <label class="mc-label">What type of collection do you want?</label>
      <div>
        <div class="cf-mode-row ${W.multi ? 'selected' : ''}" data-multi="1">
          <div class="cf-mode-radio"></div>
          <div>
            <div class="cf-mode-title">Multiple item collection <span style="font-weight:500; color:var(--mc-text-3);">(Default)</span></div>
            <div class="cf-mode-desc">Manage multiple items in a table and display them on dynamic pages or site elements.</div>
          </div>
        </div>
        <div class="cf-mode-row ${!W.multi ? 'selected' : ''}" data-multi="0">
          <div class="cf-mode-radio"></div>
          <div>
            <div class="cf-mode-title">Single item collection</div>
            <div class="cf-mode-desc">Manage a single item in a form separately from the design and display it on the site (e.g., in a homepage, header or footer).</div>
          </div>
        </div>
      </div>`;
  }

  function wzCatalog() {
    const sg = W.suggested;
    const row = (k, label, locked) => `
      <label class="cf-sg-row ${locked ? 'locked' : ''}">
        <input type="checkbox" data-sg="${k}" ${sg[k] ? 'checked' : ''} ${locked ? 'disabled' : ''}/>
        ${label}
      </label>`;
    return `
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="mc-label">Catalog collection name</label>
          <input class="mc-input" id="cf-coll-name" placeholder="e.g., Products" value="${W.collName || ''}"/>
        </div>
        <div>
          <label class="mc-label">Catalog collection ID</label>
          <input class="mc-input font-mono" id="cf-coll-id" placeholder="e.g., products" value="${W.collId || ''}"/>
        </div>
      </div>
      <div class="cf-help mt-3">${I.info} Suggested fields below. You can always add more later.</div>
      <div class="mc-divider mt-4 mb-4"></div>
      <div class="cf-sg-grid">
        <div>
          <div class="cf-sg-col-label">Essentials</div>
          ${row('name',        'Name',        true)}
          ${row('price',       'Price',       true)}
          ${row('image',       'Image',       false)}
          ${row('description', 'Description', false)}
        </div>
        <div>
          <div class="cf-sg-col-label">Fulfillment</div>
          ${row('digitalFile', 'Digital file', false)}
        </div>
      </div>`;
  }

  function wzCategory() {
    return `
      <div>
        <label class="mc-label">Category collection name</label>
        <input class="mc-input" id="cf-coll-name" placeholder="e.g., Genres" value="${W.collName || ''}"/>
      </div>
      <div class="mt-4">
        <label class="mc-label">Category collection ID</label>
        <input class="mc-input font-mono" id="cf-coll-id" placeholder="e.g., genres" value="${W.collId || ''}"/>
      </div>
      <div class="cf-help mt-4">${I.info} Categories link to items via a Category field on the parent collection, and auto-generate dynamic pages at <code class="font-mono">/category/:slug</code>.</div>`;
  }

  function wizardFoot() {
    if (W.step === 'type') {
      return `
        <button class="mc-btn mc-btn-sm mc-btn-ghost" data-cf-close>Cancel</button>
        <button class="mc-btn mc-btn-sm mc-btn-primary" data-cf-next>Next ${I.chev}</button>`;
    }
    if (W.step === 'contentStart') {
      return `
        <button class="mc-btn mc-btn-sm mc-btn-secondary" data-cf-back>${I.cbk} Back</button>
        <button class="mc-btn mc-btn-sm mc-btn-ghost" data-cf-close>Cancel</button>
        <button class="mc-btn mc-btn-sm mc-btn-primary" data-cf-next>Next ${I.chev}</button>`;
    }
    // final step
    return `
      <button class="mc-btn mc-btn-sm mc-btn-secondary" data-cf-back>${I.cbk} Back</button>
      <button class="mc-btn mc-btn-sm mc-btn-ghost" data-cf-close>Cancel</button>
      <button class="mc-btn mc-btn-sm mc-btn-primary" data-cf-create>${W.step === 'contentName' ? 'Create' : 'Create Collection'}</button>`;
  }

  function bindWizard() {
    const r = $('#cf-wizard');
    r.querySelectorAll('[data-cf-close]').forEach(b => b.onclick = hideAll);
    r.querySelectorAll('[data-coll-type]').forEach(el => el.onclick = () => { W.collType = el.dataset.collType; renderWizard(); });
    r.querySelectorAll('[data-start-mode]').forEach(el => el.onclick = () => { W.startMode = el.dataset.startMode; renderWizard(); });
    r.querySelectorAll('[data-multi]').forEach(el => el.onclick = () => { W.multi = el.dataset.multi === '1'; renderWizard(); });
    r.querySelectorAll('[data-sg]').forEach(cb => cb.onchange = () => { W.suggested[cb.dataset.sg] = cb.checked; });
    const nameInput = r.querySelector('#cf-coll-name');
    const idInput   = r.querySelector('#cf-coll-id');
    if (nameInput) nameInput.oninput = () => {
      W.collName = nameInput.value;
      if (!W.collId || W.collId === camelize(W._lastName || '')) { W.collId = camelize(W.collName); idInput.value = W.collId; }
      W._lastName = W.collName;
    };
    if (idInput) idInput.oninput = () => { W.collId = idInput.value; };

    const next = r.querySelector('[data-cf-next]');
    if (next) next.onclick = () => {
      if (W.step === 'type') {
        if (W.collType === 'content')       W.step = 'contentStart';
        else if (W.collType === 'catalog')  W.step = 'catalog';
        else                                W.step = 'category';
        renderWizard();
      } else if (W.step === 'contentStart') {
        W.step = 'contentName'; renderWizard();
      }
    };
    const back = r.querySelector('[data-cf-back]');
    if (back) back.onclick = () => {
      if (W.step === 'contentStart' || W.step === 'catalog' || W.step === 'category') W.step = 'type';
      else if (W.step === 'contentName') W.step = 'contentStart';
      renderWizard();
    };
    const create = r.querySelector('[data-cf-create]');
    if (create) create.onclick = () => { hideAll(); /* in a real flow we'd persist the collection */ };
  }

  // ─────────────────────────────────────────────────────────────
  //  MANAGE-FIELDS SIDE PANEL
  // ─────────────────────────────────────────────────────────────
  // Demo fields list mirrors the existing Titles columns
  let MANAGED_FIELDS = [
    { id:'title',    label:'Title',      typeId:'text',    primary:true,  on:true,  system:false },
    { id:'author',   label:'Author',     typeId:'ref',     primary:false, on:true,  system:false },
    { id:'isbn',     label:'ISBN',       typeId:'text',    primary:false, on:true,  system:false },
    { id:'genre',    label:'Genre',      typeId:'cat',     primary:false, on:true,  system:false },
    { id:'price',    label:'Price',      typeId:'number',  primary:false, on:true,  system:false },
    { id:'stock',    label:'Stock',      typeId:'number',  primary:false, on:false, system:false },
    { id:'cover',    label:'Cover',      typeId:'image',   primary:false, on:true,  system:false },
    { id:'_id',      label:'ID',         typeId:'text',    primary:false, on:false, system:true  },
    { id:'_created', label:'Created date',typeId:'date',   primary:false, on:false, system:true  },
    { id:'_updated', label:'Updated date',typeId:'date',   primary:false, on:false, system:true  },
    { id:'_owner',   label:'Owner',      typeId:'ref',     primary:false, on:false, system:true  },
  ];

  function openPanel() { P.open = true; renderPanel(); $('#cf-panel-backdrop').classList.add('open'); $('#cf-panel').classList.add('open'); }
  function closePanel() { P.open = false; $('#cf-panel-backdrop').classList.remove('open'); $('#cf-panel').classList.remove('open'); }

  function renderPanel() {
    const root = $('#cf-panel');
    root.innerHTML = `
      <div class="cf-panel-head">
        <div>
          <div class="font-display font-bold text-base" style="letter-spacing: -0.01em;">Manage Fields</div>
          <div class="text-xs mt-1" style="color: var(--mc-text-3);">Choose which fields appear in the collection. Changes will only be shown in this view.</div>
        </div>
        <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-cf-panel-close>${I.x}</button>
      </div>
      <div class="cf-panel-body">
        ${MANAGED_FIELDS.map(f => fieldRow(f)).join('')}
      </div>
      <div class="cf-panel-foot">
        <button class="mc-btn mc-btn-sm mc-btn-primary w-full" style="width:100%;" data-cf-add-field>${I.plus} Add Field</button>
      </div>`;
    root.querySelector('[data-cf-panel-close]').onclick = closePanel;
    root.querySelector('[data-cf-add-field]').onclick = () => { closePanel(); openChooseType(); };
    root.querySelectorAll('[data-toggle-field]').forEach(cb => cb.onchange = () => {
      const f = MANAGED_FIELDS.find(x => x.id === cb.dataset.toggleField);
      if (f) f.on = cb.checked;
    });
  }

  function fieldRow(f) {
    const t = findType(f.typeId);
    const tag = f.primary ? '<span class="cf-field-tag primary">Primary</span>'
              : f.system  ? '<span class="cf-field-tag">System</span>' : '';
    return `
      <div class="cf-field-row">
        <span class="cf-field-grip">${I.grip}</span>
        <input type="checkbox" data-toggle-field="${f.id}" ${f.on ? 'checked' : ''} ${f.primary ? 'disabled' : ''}/>
        <span class="cf-field-type-icon">${I[t?.icon || 'text']}</span>
        <span class="cf-field-name">${f.label}</span>
        ${tag}
      </div>`;
  }

  // ─────────────────────────────────────────────────────────────
  //  CHOOSE FIELD TYPE
  // ─────────────────────────────────────────────────────────────
  function openChooseType() {
    F.change = false;
    renderChooseType();
    show('cf-choose');
  }
  function openChangeType() {
    F.change = true;
    renderChooseType();
    show('cf-choose');
  }

  function renderChooseType() {
    const root = $('#cf-choose');
    root.innerHTML = `
      <div class="mc-modal cf-modal cf-wide">
        <div class="mc-modal-head">
          <div>
            <div class="font-display font-bold text-lg">${F.change ? 'Change field type' : 'Choose field type'}</div>
            <div class="text-xs mt-0.5" style="color: var(--mc-text-3);">You can connect each field to a page element to display its content on your site.</div>
          </div>
          <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-cf-close>${I.x}</button>
        </div>
        <div class="mc-modal-body">${ftGroups()}</div>
        <div class="mc-modal-foot">
          <button class="mc-btn mc-btn-sm mc-btn-ghost" data-cf-close>Cancel</button>
          <button class="mc-btn mc-btn-sm mc-btn-primary" data-cf-pick>${F.change ? 'Change Field Type' : 'Choose Field Type'}</button>
        </div>
      </div>`;
    bindChooseType();
  }

  function ftGroups() {
    return GROUPS.map(g => `
      <div class="cf-group-label">${g.label}</div>
      <div class="cf-ft-grid">
        ${TYPES.filter(t => t.group === g.id).map(t => `
          <div class="cf-ft-card ${F.type === t.id ? 'selected' : ''}" data-type="${t.id}">
            <span class="cf-ft-icon">${I[t.icon]}</span>
            <div>
              <div class="cf-ft-title">${t.label}</div>
              <div class="cf-ft-desc">${t.desc}</div>
            </div>
          </div>`).join('')}
      </div>`).join('');
  }

  function bindChooseType() {
    const r = $('#cf-choose');
    r.querySelectorAll('[data-cf-close]').forEach(b => b.onclick = hideAll);
    r.querySelectorAll('[data-type]').forEach(c => c.onclick = () => { F.type = c.dataset.type; renderChooseType(); });
    r.querySelector('[data-cf-pick]').onclick = () => {
      const wasChange = F.change;
      F.change = false;
      if (!wasChange) {
        // reset field draft
        const t = findType(F.type);
        F.tab = 'settings';
        F.name = t.label;
        F.id   = camelize(t.label);
        F.help = '';
        F.vals = { required: false };
      }
      openAddField();
    };
  }

  // ─────────────────────────────────────────────────────────────
  //  ADD A FIELD (Settings / Validations / Default value)
  // ─────────────────────────────────────────────────────────────
  function openAddField() { renderAddField(); show('cf-add'); }

  function renderAddField() {
    const t = findType(F.type);
    const root = $('#cf-add');
    root.innerHTML = `
      <div class="mc-modal cf-modal">
        <div class="mc-modal-head" style="padding-bottom: 0;">
          <div>
            <div class="font-display font-bold text-lg">Add a field</div>
            <div class="text-xs mt-0.5" style="color: var(--mc-text-3);">Configure how this field appears and behaves.</div>
          </div>
          <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-cf-close>${I.x}</button>
        </div>
        <div class="cf-tabs">
          <button class="cf-tab ${F.tab === 'settings'    ? 'active' : ''}" data-tab="settings">Settings</button>
          <button class="cf-tab ${F.tab === 'validations' ? 'active' : ''}" data-tab="validations">Validations</button>
          <button class="cf-tab ${F.tab === 'defaultValue'? 'active' : ''}" data-tab="defaultValue">Default value</button>
        </div>
        <div class="mc-modal-body">
          ${F.tab === 'settings'     ? addSettings(t) : ''}
          ${F.tab === 'validations'  ? addValidations(t) : ''}
          ${F.tab === 'defaultValue' ? addDefaultValue(t) : ''}
        </div>
        <div class="mc-modal-foot">
          <button class="mc-btn mc-btn-sm mc-btn-secondary" data-cf-back-choose>${I.cbk} Back</button>
          <div style="flex:1"></div>
          <button class="mc-btn mc-btn-sm mc-btn-ghost" data-cf-close>Cancel</button>
          <button class="mc-btn mc-btn-sm mc-btn-primary" data-cf-save>Save</button>
        </div>
      </div>`;
    bindAddField();
  }

  function addSettings(t) {
    const extras = (t.extras || []).map(e => {
      if (e === 'refCollection') {
        return `
          <div class="mt-4">
            <label class="mc-label">Referenced collection <span style="color:var(--mc-brand)">*</span></label>
            <select class="mc-input mc-select"><option>Authors</option><option>Genres</option><option>Titles</option></select>
          </div>`;
      }
      if (e === 'catCollection') {
        return `
          <div class="mt-4">
            <label class="mc-label">Category collection <span style="color:var(--mc-brand)">*</span></label>
            <select class="mc-input mc-select" id="cf-cat-coll"><option>Root</option><option>Genres</option><option>Tags</option></select>
            <div class="cf-help">${I.info} A Category collection groups items together and auto-generates dynamic category pages.</div>
          </div>`;
      }
      return '';
    }).join('');
    return `
      <label class="mc-label">Field type <span style="color:var(--mc-brand)">*</span></label>
      <div class="cf-field-type-pill">
        ${I[t.icon]}
        <span>${t.label}</span>
        <button class="cf-chg" data-cf-change-type>Change</button>
      </div>
      ${extras}
      <div class="grid grid-cols-2 gap-4 mt-4">
        <div>
          <label class="mc-label">Field name <span style="color:var(--mc-brand)">*</span></label>
          <input class="mc-input" id="cf-fname" value="${F.name}"/>
        </div>
        <div>
          <label class="mc-label">Field ID <span style="color:var(--mc-brand)">*</span></label>
          <input class="mc-input font-mono" id="cf-fid" value="${F.id}"/>
        </div>
      </div>
      <div class="mt-4">
        <label class="mc-label">Help text (optional)</label>
        <input class="mc-input" id="cf-fhelp" value="${F.help}" placeholder="Shown beneath the field in the editor."/>
      </div>`;
  }

  function addValidations(t) {
    const rows = t.val.map(k => valRow(k)).join('');
    return `<div class="cf-val-list">${rows}</div>`;
  }

  function valRow(key) {
    const v = VAL[key];
    if (!v) return '';
    const cur = F.vals[key];
    let ctrl = '';
    if (v.kind === 'toggle') {
      ctrl = `<label class="cf-switch"><input type="checkbox" data-val="${key}" ${cur ? 'checked' : ''}/><span></span></label>`;
    } else if (v.kind === 'number') {
      ctrl = `<input class="mc-input" type="number" data-val="${key}" placeholder="${v.placeholder || ''}" value="${cur ?? ''}" style="width:110px;"/>`;
    } else if (v.kind === 'text') {
      ctrl = `<input class="mc-input font-mono" type="text" data-val="${key}" placeholder="${v.placeholder || ''}" value="${cur ?? ''}" style="width:220px;"/>`;
    } else if (v.kind === 'date') {
      ctrl = `<input class="mc-input" type="date" data-val="${key}" value="${cur ?? ''}" style="width:170px;"/>`;
    } else if (v.kind === 'time') {
      ctrl = `<input class="mc-input" type="time" data-val="${key}" value="${cur ?? ''}" style="width:130px;"/>`;
    } else if (v.kind === 'unit') {
      ctrl = `<div class="cf-val-ctrl-unit">
        <input class="mc-input" type="number" data-val="${key}" placeholder="${v.placeholder || ''}" value="${cur?.n ?? ''}"/>
        <select class="mc-input mc-select" data-val-unit="${key}">${v.units.map(u => `<option ${cur?.u === u || (u === v.defaultUnit && !cur?.u) ? 'selected' : ''}>${u}</option>`).join('')}</select>
      </div>`;
    } else if (v.kind === 'wh') {
      ctrl = `<div class="cf-val-ctrl-wh">
        <input class="mc-input" type="number" data-val="${key}-w" placeholder="W" value="${cur?.w ?? ''}"/>
        <span style="color:var(--mc-text-3); font-size:12px;">×</span>
        <input class="mc-input" type="number" data-val="${key}-h" placeholder="H" value="${cur?.h ?? ''}"/>
      </div>`;
    }
    return `
      <div class="cf-val-row">
        <div>
          <div class="cf-val-label">${v.label}</div>
          ${v.help ? `<div class="cf-val-help">${v.help}</div>` : ''}
        </div>
        <div class="cf-val-ctrl">${ctrl}</div>
      </div>`;
  }

  function addDefaultValue(t) {
    if (!t.def) {
      return `<div class="cf-info-box">
        <strong>${t.defNote || `"${t.label}"`} fields do not support default values</strong>
        <p style="margin-top:6px; color:var(--mc-text-2);">Default values are supported for the following field types: Text, Email, Image, Boolean, Number, Date and Time, Date, Color, URL, Video, Audio, Address, Tags, Array, Object, Rich Content.</p>
        <p style="margin-top:8px; color:var(--mc-text-2);">Think "${t.label}" fields should support default values? <a href="#">Submit a request</a></p>
      </div>`;
    }
    let input = '';
    if (t.id === 'text' || t.id === 'url' || t.id === 'email') {
      input = `<input class="mc-input" placeholder="Default ${t.label.toLowerCase()}…"/>`;
    } else if (t.id === 'number') {
      input = `<input class="mc-input" type="number" placeholder="0"/>`;
    } else if (t.id === 'bool') {
      input = `<label class="cf-switch"><input type="checkbox"/><span></span></label> <span style="color:var(--mc-text-2); font-size:13px; margin-left:8px;">Default to <strong>true</strong></span>`;
    } else if (t.id === 'color') {
      input = `<div style="display:flex; gap:8px; align-items:center;"><input type="color" value="#d97a3c" style="width:42px; height:32px; border:1px solid var(--mc-border); border-radius:8px; padding:0; background:transparent;"/><input class="mc-input font-mono" value="#D97A3C" style="width:140px;"/></div>`;
    } else if (t.id === 'date') {
      input = `<input class="mc-input" type="date" style="width:180px;"/>`;
    } else if (t.id === 'tags' || t.id === 'arr') {
      input = `<input class="mc-input" placeholder="Comma-separated values…"/>`;
    } else if (t.id === 'addr') {
      input = `<input class="mc-input" placeholder="Search an address…"/>`;
    } else if (t.id === 'image' || t.id === 'video' || t.id === 'audio') {
      input = `<button class="mc-btn mc-btn-sm mc-btn-secondary">${I.plus} Choose file</button>`;
    } else if (t.id === 'obj') {
      input = `<textarea class="mc-input font-mono" rows="6" placeholder='{ "key": "value" }'></textarea>`;
    } else if (t.id === 'richc') {
      input = `<textarea class="mc-input" rows="4" placeholder="Default content…"></textarea>`;
    } else {
      input = `<input class="mc-input" placeholder="Default value…"/>`;
    }
    return `
      <label class="mc-label">Default value</label>
      ${input}
      <div class="cf-help mt-3">${I.info} This value is used whenever a new ${t.label.toLowerCase()} record is created without one supplied.</div>`;
  }

  function bindAddField() {
    const r = $('#cf-add');
    r.querySelectorAll('[data-cf-close]').forEach(b => b.onclick = hideAll);
    r.querySelectorAll('[data-tab]').forEach(b => b.onclick = () => { F.tab = b.dataset.tab; renderAddField(); });
    const back = r.querySelector('[data-cf-back-choose]');
    if (back) back.onclick = () => { hideAll(); openChooseType(); };
    const chg = r.querySelector('[data-cf-change-type]');
    if (chg) chg.onclick = () => { hideAll(); openChangeType(); };
    const fname = r.querySelector('#cf-fname');
    const fid   = r.querySelector('#cf-fid');
    if (fname) fname.oninput = () => {
      F.name = fname.value;
      if (F.id === camelize(F._lastName || '')) { F.id = camelize(F.name); if (fid) fid.value = F.id; }
      F._lastName = F.name;
    };
    if (fid) fid.oninput = () => { F.id = fid.value; };
    const fh = r.querySelector('#cf-fhelp');
    if (fh) fh.oninput = () => { F.help = fh.value; };
    r.querySelectorAll('[data-val]').forEach(c => {
      c.onchange = () => {
        const k = c.dataset.val;
        if (c.type === 'checkbox') F.vals[k] = c.checked;
        else if (k.endsWith('-w') || k.endsWith('-h')) {
          const base = k.replace(/-[wh]$/, ''); const dim = k.slice(-1);
          F.vals[base] = F.vals[base] || {}; F.vals[base][dim] = c.value;
        } else if (VAL[k]?.kind === 'unit') {
          F.vals[k] = F.vals[k] || {}; F.vals[k].n = c.value;
        } else F.vals[k] = c.value;
      };
    });
    r.querySelectorAll('[data-val-unit]').forEach(c => {
      c.onchange = () => { const k = c.dataset.valUnit; F.vals[k] = F.vals[k] || {}; F.vals[k].u = c.value; };
    });
    const save = r.querySelector('[data-cf-save]');
    if (save) save.onclick = () => {
      // append to managed fields for demo
      MANAGED_FIELDS.push({
        id: F.id || slugify(F.name),
        label: F.name || 'Untitled',
        typeId: F.type,
        primary: false,
        on: true,
        system: false,
      });
      hideAll();
      // refresh panel if it was opened
      if (P.open) { renderPanel(); $('#cf-panel-backdrop').classList.add('open'); $('#cf-panel').classList.add('open'); }
    };
  }

  // ─────────────────────────────────────────────────────────────
  //  MODAL VISIBILITY
  // ─────────────────────────────────────────────────────────────
  function show(id) {
    hideAllModals();
    const el = document.getElementById(id);
    if (el) el.style.display = 'grid';
  }
  function hideAllModals() {
    ['cf-wizard','cf-choose','cf-add'].forEach(id => {
      const el = document.getElementById(id); if (el) el.style.display = 'none';
    });
  }
  function hideAll() { hideAllModals(); }

  // ─────────────────────────────────────────────────────────────
  //  INIT — wire up triggers and expose openers globally
  // ─────────────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('[data-cf-open-wizard]').forEach(b => b.addEventListener('click', openWizard));
    document.querySelectorAll('[data-cf-open-panel]').forEach(b => b.addEventListener('click', openPanel));
    document.querySelectorAll('[data-cf-open-add]').forEach(b => b.addEventListener('click', openChooseType));
    // backdrop closes
    document.querySelectorAll('.mc-modal-backdrop[data-cf]').forEach(bd => {
      bd.addEventListener('click', e => { if (e.target === bd) hideAll(); });
    });
    const pb = document.getElementById('cf-panel-backdrop');
    if (pb) pb.addEventListener('click', closePanel);
    document.addEventListener('keydown', e => { if (e.key === 'Escape') { hideAll(); closePanel(); } });
  });

  window.CF = { openWizard, openPanel, openChooseType, openChangeType };
})();
