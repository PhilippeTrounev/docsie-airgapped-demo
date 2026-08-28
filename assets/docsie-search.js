/**
 * Docsie Offline Search Plugin
 *
 * Client-side full-text search for air-gapped portal deployments. The plugin
 * loads /search/index.json, mounts into the reader's nav-plugin-bar through
 * PluginBaseClass, and never calls a hosted search service.
 */
(function() {
  'use strict';

  var searchIndex = null;
  var documents = [];
  var isLoaded = false;
  var loadPromise = null;
  var invertedIndex = {};
  var documentMap = {};
  var indexTokens = [];
  var modalTriggerFn = null;
  var searchPlugin = null;
  var registrationAttempts = 0;
  var ui = {
    container: null,
    launcherInput: null,
    fallbackLauncher: null,
    fallbackInput: null,
    modal: null,
    modalInput: null,
    results: null,
    status: null,
    firstResultUrl: null
  };

  var STYLES = [
    '.docsie-offline-search-plugin-container{box-sizing:border-box;width:100%;padding:0 16px 14px;}',
    '.docsie-offline-search-launcher{align-items:center;background:#fff;border:1px solid #d7dce2;border-radius:8px;box-sizing:border-box;color:#57606a;display:flex;gap:8px;min-height:40px;padding:0 10px;width:100%;}',
    '.docsie-offline-search-launcher:focus-within{border-color:#3978f6;box-shadow:0 0 0 3px rgba(57,120,246,.15);}',
    '.docsie-offline-search-launcher-icon{font-size:18px;line-height:1;}',
    '.docsie-offline-search-launcher input{background:transparent;border:0;box-sizing:border-box;color:#1f2328;font:inherit;min-width:0;outline:0;padding:8px 0;width:100%;}',
    '.docsie-offline-search-launcher input::placeholder{color:#667085;}',
    '.docsie-offline-search-shortcut{background:#f4f6f8;border:1px solid #d7dce2;border-radius:4px;color:#57606a;font:11px/1.4 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:1px 5px;white-space:nowrap;}',
    '.docsie-offline-search-global-shell{background:#fff;border:2px solid #3978f6;border-radius:10px;box-sizing:border-box;position:fixed;right:20px;top:16px;width:min(320px,calc(100vw - 40px));z-index:2147483646;}',
    '.docsie-offline-search-global-shell .docsie-offline-search-launcher{border:0;box-shadow:0 8px 28px rgba(15,23,42,.28);}',
    '.docsie-offline-search-modal[hidden]{display:none!important;}',
    '.docsie-offline-search-modal{align-items:flex-start;background:rgba(15,23,42,.55);box-sizing:border-box;display:flex;inset:0;justify-content:center;overflow:auto;padding:8vh 16px 32px;position:fixed;z-index:2147483000;}',
    '.docsie-offline-search-dialog{background:#fff;border-radius:12px;box-shadow:0 24px 80px rgba(15,23,42,.35);box-sizing:border-box;color:#1f2328;display:flex;flex-direction:column;max-height:84vh;max-width:760px;overflow:hidden;width:100%;}',
    '.docsie-offline-search-header{align-items:center;border-bottom:1px solid #e5e7eb;display:flex;gap:10px;padding:14px 16px;}',
    '.docsie-offline-search-header-icon{color:#57606a;font-size:20px;}',
    '.docsie-offline-search-input{background:transparent;border:0;color:#111827;flex:1;font:500 18px/1.4 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;min-width:0;outline:0;padding:4px 0;}',
    '.docsie-offline-search-close{align-items:center;background:#f4f6f8;border:1px solid #d7dce2;border-radius:6px;color:#374151;cursor:pointer;display:flex;font:20px/1 sans-serif;height:32px;justify-content:center;width:32px;}',
    '.docsie-offline-search-status{color:#667085;font:13px/1.4 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:10px 18px 0;}',
    '.docsie-offline-search-results{list-style:none;margin:0;overflow:auto;padding:10px;}',
    '.docsie-offline-search-result{border-radius:8px;margin:0;padding:0;}',
    '.docsie-offline-search-result+.docsie-offline-search-result{border-top:1px solid #edf0f3;}',
    '.docsie-offline-search-result a{color:inherit;display:block;padding:13px 12px;text-decoration:none;}',
    '.docsie-offline-search-result a:hover,.docsie-offline-search-result a:focus{background:#f3f7ff;outline:0;}',
    '.docsie-offline-search-result-title{color:#174ea6;display:block;font:600 16px/1.35 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;}',
    '.docsie-offline-search-result-context{color:#667085;display:block;font:12px/1.4 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;margin-top:3px;}',
    '.docsie-offline-search-result-snippet{color:#374151;display:block;font:13px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;margin-top:6px;}',
    '.docsie-offline-search-empty{color:#667085;font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:28px 18px;text-align:center;}',
    '@media(max-width:640px){.docsie-offline-search-global-shell{left:12px;right:12px;top:12px;width:auto}.docsie-offline-search-modal{padding:0}.docsie-offline-search-dialog{border-radius:0;max-height:100vh;min-height:100vh}.docsie-offline-search-shortcut{display:none}}',
    '@media print{.docsie-offline-search-global-shell{display:none!important}}',
    '@media(prefers-color-scheme:dark){.docsie-offline-search-launcher,.docsie-offline-search-dialog{background:#171a21;color:#f3f4f6}.docsie-offline-search-launcher{border-color:#3f4652}.docsie-offline-search-launcher input,.docsie-offline-search-input{color:#f3f4f6}.docsie-offline-search-header,.docsie-offline-search-result+.docsie-offline-search-result{border-color:#343b46}.docsie-offline-search-result a:hover,.docsie-offline-search-result a:focus{background:#202a3a}.docsie-offline-search-result-title{color:#8ab4f8}.docsie-offline-search-result-snippet{color:#d1d5db}}'
  ].join('\n');

  function tokenize(text) {
    if (!text) return [];
    return String(text)
      .toLowerCase()
      .replace(/[^\w\s]/g, ' ')
      .split(/\s+/)
      .filter(function(token) { return token.length > 1; });
  }

  function buildIndex(docs) {
    invertedIndex = {};
    documentMap = {};

    docs.forEach(function(doc) {
      documentMap[doc.id] = doc;
      addTokens(doc.id, tokenize(doc.title || doc.article_name || ''), 3);
      addTokens(doc.id, tokenize(doc.content || doc.text || ''), 1);

      if (Array.isArray(doc.tags)) {
        doc.tags.forEach(function(tag) {
          addTokens(doc.id, tokenize(tag), 2);
        });
      }
    });

    indexTokens = Object.keys(invertedIndex);
  }

  function addTokens(documentId, tokens, weight) {
    tokens.forEach(function(token) {
      if (!invertedIndex[token]) invertedIndex[token] = {};
      invertedIndex[token][documentId] =
        (invertedIndex[token][documentId] || 0) + weight;
    });
  }

  function loadIndex() {
    if (loadPromise) return loadPromise;

    loadPromise = fetch('/search/index.json')
      .then(function(response) {
        if (!response.ok) {
          throw new Error('Failed to load local search index');
        }
        return response.json();
      })
      .then(function(data) {
        searchIndex = data;
        documents = data.documents || [];
        buildIndex(documents);
        isLoaded = true;
        setLauncherState();
        return true;
      })
      .catch(function(error) {
        console.error('Offline search: Failed to load index', error);
        isLoaded = false;
        loadPromise = null;
        setLauncherState();
        return false;
      });

    return loadPromise;
  }

  function search(query, options) {
    options = options || {};
    var limit = options.limit || 20;
    var language = options.language;
    var version = options.version;

    if (!isLoaded || !query || query.length < 2) return [];

    var queryTokens = tokenize(query);
    if (queryTokens.length === 0) return [];

    var scores = {};
    queryTokens.forEach(function(token) {
      addMatches(scores, invertedIndex[token], 1);

      indexTokens.forEach(function(indexToken) {
        if (indexToken !== token && indexToken.indexOf(token) === 0) {
          addMatches(scores, invertedIndex[indexToken], 0.5);
        }
      });
    });

    var results = Object.keys(scores).map(function(documentId) {
      return {
        id: documentId,
        score: scores[documentId],
        document: documentMap[documentId]
      };
    });

    if (language) {
      results = results.filter(function(result) {
        var docLanguage =
          result.document.language_abbreviation || result.document.language;
        return docLanguage === language;
      });
    }

    if (version) {
      results = results.filter(function(result) {
        var docVersion =
          result.document.version_number || result.document.version;
        return docVersion === version;
      });
    }

    results.sort(function(left, right) {
      return right.score - left.score;
    });

    return results.slice(0, limit).map(function(result) {
      return formatResult(result, queryTokens, query);
    });
  }

  function addMatches(scores, matches, multiplier) {
    if (!matches) return;
    Object.keys(matches).forEach(function(documentId) {
      scores[documentId] =
        (scores[documentId] || 0) + (matches[documentId] * multiplier);
    });
  }

  function formatResult(result, queryTokens, query) {
    var doc = result.document;
    var articleName = doc.article_name || doc.title || '';
    var text = doc.text || doc.content || '';
    return {
      id: { raw: doc.id },
      article_id: { raw: doc.article_id || '' },
      article_name: {
        raw: articleName,
        snippet: highlightSnippet(articleName, queryTokens)
      },
      text: {
        raw: text,
        snippet: getContentSnippet(text, queryTokens)
      },
      doc_name: { raw: doc.doc_name || '' },
      book_name: { raw: doc.book_name || '' },
      doc_slug: { raw: doc.doc_slug || doc.doc_id || '' },
      book_slug: { raw: doc.book_slug || doc.book_id || '' },
      article_slug: {
        raw: doc.article_slug || doc.article_id || doc.id
      },
      language_abbreviation: {
        raw: doc.language_abbreviation || doc.language || ''
      },
      version_number: {
        raw: doc.version_number || doc.version || ''
      },
      query: {
        raw: query,
        snippet: highlightSnippet(query, queryTokens)
      },
      path: { raw: doc.path || '' },
      _meta: { score: result.score }
    };
  }

  function highlightSnippet(text, tokens) {
    if (!text) return '';
    var result = String(text);
    tokens.forEach(function(token) {
      var expression = new RegExp('(' + escapeRegex(token) + ')', 'gi');
      result = result.replace(expression, '<em>$1</em>');
    });
    return result;
  }

  function getContentSnippet(content, tokens) {
    if (!content) return '';
    return highlightSnippet(plainSnippet(content, tokens.join(' ')), tokens);
  }

  function plainSnippet(content, query) {
    if (!content) return '';
    var text = String(content).replace(/\s+/g, ' ').trim();
    var tokens = tokenize(query);
    var lowerText = text.toLowerCase();
    var firstMatch = -1;

    tokens.forEach(function(token) {
      var position = lowerText.indexOf(token);
      if (position !== -1 && (firstMatch === -1 || position < firstMatch)) {
        firstMatch = position;
      }
    });

    var start = firstMatch > 60 ? firstMatch - 60 : 0;
    var end = Math.min(text.length, start + 190);
    var snippet = text.substring(start, end);
    if (start > 0) snippet = '\u2026' + snippet;
    if (end < text.length) snippet += '\u2026';
    return snippet;
  }

  function escapeRegex(value) {
    return String(value).replace(/[.*+?^$(){}|[\]\\]/g, '\\$&');
  }

  function raw(result, fieldName) {
    return result[fieldName] && result[fieldName].raw
      ? result[fieldName].raw
      : '';
  }

  function createElement(tagName, className, text) {
    var element = document.createElement(tagName);
    if (className) element.className = className;
    if (text !== undefined && text !== null) element.textContent = text;
    return element;
  }

  function createSearchIcon(className) {
    var namespace = 'http://www.w3.org/2000/svg';
    var icon = document.createElementNS(namespace, 'svg');
    var path = document.createElementNS(namespace, 'path');
    icon.setAttribute('class', className);
    icon.setAttribute('viewBox', '0 0 16 16');
    icon.setAttribute('width', '18');
    icon.setAttribute('height', '18');
    icon.setAttribute('aria-hidden', 'true');
    path.setAttribute('d', 'M11.25 11.25 15 15m-2-8A6 6 0 1 1 1 7a6 6 0 0 1 12 0Z');
    path.setAttribute('fill', 'none');
    path.setAttribute('stroke', 'currentColor');
    path.setAttribute('stroke-linecap', 'round');
    path.setAttribute('stroke-width', '1.5');
    icon.appendChild(path);
    return icon;
  }

  function renderPlugin(component, container) {
    if (container.getAttribute('data-docsie-offline-search-mounted') === 'true') {
      return;
    }

    container.setAttribute('data-docsie-offline-search-mounted', 'true');
    ui.container = container;

    ui.launcherInput = createLauncher(container);

    createModal();
    ensureGlobalLauncher();
    loadIndex().then(setLauncherState);
  }

  function createLauncher(container) {
    var launcher = createElement('div', 'docsie-offline-search-launcher');
    launcher.setAttribute('role', 'search');

    var icon = createSearchIcon('docsie-offline-search-launcher-icon');

    var input = createElement('input');
    input.type = 'search';
    input.placeholder = 'Loading offline search\u2026';
    input.disabled = true;
    input.setAttribute('aria-label', 'Search offline documentation');
    input.setAttribute('autocomplete', 'off');

    var shortcut = createElement(
      'kbd',
      'docsie-offline-search-shortcut',
      isMacPlatform() ? '\u2318K' : 'Ctrl K'
    );

    launcher.appendChild(icon);
    launcher.appendChild(input);
    launcher.appendChild(shortcut);
    container.appendChild(launcher);
    input.addEventListener('focus', function() {
      openModal(input.value);
    });
    input.addEventListener('click', function() {
      openModal(input.value);
    });
    return input;
  }

  function ensureGlobalLauncher() {
    if (ui.fallbackLauncher) return;

    var fallback = createElement(
      'div',
      'docsie-offline-search-global-shell docsie-print-hidden'
    );
    fallback.setAttribute('data-docsie-offline-search-fallback', 'true');
    document.body.appendChild(fallback);
    ui.fallbackLauncher = fallback;
    ui.fallbackInput = createLauncher(fallback);
    setLauncherState();
  }

  function setLauncherState() {
    launcherInputs().forEach(function(input) {
      input.disabled = !isLoaded;
      input.placeholder = isLoaded
        ? 'Search offline documentation\u2026'
        : 'Offline search unavailable';
    });
  }

  function launcherInputs() {
    return [ui.launcherInput, ui.fallbackInput].filter(Boolean);
  }

  function setLauncherValues(value) {
    launcherInputs().forEach(function(input) {
      input.value = value;
    });
  }

  function createModal() {
    if (ui.modal) return;

    var modal = createElement('div', 'docsie-offline-search-modal');
    modal.hidden = true;
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-labelledby', 'DocsieOfflineSearchLabel');

    var dialog = createElement('div', 'docsie-offline-search-dialog');
    var header = createElement('div', 'docsie-offline-search-header');
    var icon = createSearchIcon('docsie-offline-search-header-icon');

    var input = createElement('input', 'docsie-offline-search-input');
    input.id = 'DocsieOfflineSearchInput';
    input.type = 'search';
    input.placeholder = 'Search this offline documentation\u2026';
    input.setAttribute('aria-label', 'Search this offline documentation');
    input.setAttribute('autocomplete', 'off');

    var label = createElement('span');
    label.id = 'DocsieOfflineSearchLabel';
    label.hidden = true;
    label.textContent = 'Offline documentation search';

    var close = createElement(
      'button',
      'docsie-offline-search-close',
      '\u00d7'
    );
    close.type = 'button';
    close.setAttribute('aria-label', 'Close search');

    var status = createElement('div', 'docsie-offline-search-status');
    status.setAttribute('aria-live', 'polite');

    var results = createElement('ol', 'docsie-offline-search-results');

    header.appendChild(icon);
    header.appendChild(input);
    header.appendChild(close);
    dialog.appendChild(label);
    dialog.appendChild(header);
    dialog.appendChild(status);
    dialog.appendChild(results);
    modal.appendChild(dialog);
    document.body.appendChild(modal);

    ui.modal = modal;
    ui.modalInput = input;
    ui.results = results;
    ui.status = status;

    input.addEventListener('input', function() {
      setLauncherValues(input.value);
      renderResults(input.value);
    });
    input.addEventListener('keydown', function(event) {
      if (event.key === 'Enter' && ui.firstResultUrl) {
        event.preventDefault();
        navigateTo(ui.firstResultUrl);
      } else if (event.key === 'ArrowDown') {
        var firstLink = ui.results.querySelector('a');
        if (firstLink) {
          event.preventDefault();
          firstLink.focus();
        }
      }
    });
    close.addEventListener('click', closeModal);
    modal.addEventListener('click', function(event) {
      if (event.target === modal) closeModal();
    });
    document.addEventListener('keydown', handleGlobalKeydown);

    modalTriggerFn = function(visible, term) {
      if (visible) openModal(term);
      else closeModal();
    };
  }

  function handleGlobalKeydown(event) {
    if (
      (event.ctrlKey || event.metaKey) &&
      String(event.key).toLowerCase() === 'k'
    ) {
      event.preventDefault();
      openModal('');
    } else if (event.key === 'Escape' && ui.modal && !ui.modal.hidden) {
      closeModal();
    }
  }

  function openModal(term) {
    if (!ui.modal) return;
    ui.modal.hidden = false;
    ui.modalInput.value = term || '';
    setLauncherValues(term || '');
    renderResults(ui.modalInput.value);
    window.setTimeout(function() {
      ui.modalInput.focus();
      ui.modalInput.select();
    }, 0);
  }

  function closeModal() {
    if (!ui.modal) return;
    ui.modal.hidden = true;
    ui.firstResultUrl = null;
    launcherInputs().forEach(function(input) { input.blur(); });
  }

  function renderResults(query) {
    ui.results.textContent = '';
    ui.firstResultUrl = null;

    if (!isLoaded) {
      setStatus('Loading the local search index\u2026');
      appendEmptyMessage('Search will be available when the index finishes loading.');
      loadIndex().then(function(loaded) {
        if (loaded && ui.modalInput && !ui.modal.hidden) {
          renderResults(ui.modalInput.value);
        }
      });
      return;
    }

    if (!query || query.trim().length < 2) {
      setStatus(searchIndex && searchIndex.meta
        ? searchIndex.meta.total_documents + ' documents available offline'
        : 'Offline search ready');
      appendEmptyMessage('Type at least two characters to search.');
      return;
    }

    var results = deduplicateResults(search(query.trim(), { limit: 100 }))
      .slice(0, 20);
    setStatus(results.length
      ? results.length + ' local result' + (results.length === 1 ? '' : 's')
      : 'No local results');

    if (!results.length) {
      appendEmptyMessage('No offline documentation matched \u201c' + query.trim() + '\u201d.');
      return;
    }

    results.forEach(function(result, index) {
      var url = resultUrl(result, query);
      if (index === 0) ui.firstResultUrl = url;
      ui.results.appendChild(createResultElement(result, query, url));
    });
  }

  function deduplicateResults(results) {
    var seen = {};
    return results.filter(function(result) {
      var key = [
        raw(result, 'doc_slug'),
        raw(result, 'book_slug'),
        raw(result, 'article_slug'),
        raw(result, 'language_abbreviation')
      ].join('|');
      if (seen[key]) return false;
      seen[key] = true;
      return true;
    });
  }

  function createResultElement(result, query, url) {
    var item = createElement('li', 'docsie-offline-search-result');
    var link = createElement('a');
    link.href = url;

    var title = createElement(
      'span',
      'docsie-offline-search-result-title',
      raw(result, 'article_name') || 'Untitled article'
    );
    var contextParts = [
      raw(result, 'doc_name'),
      raw(result, 'book_name'),
      raw(result, 'language_abbreviation'),
      raw(result, 'version_number')
    ].filter(Boolean);
    var context = createElement(
      'span',
      'docsie-offline-search-result-context',
      contextParts.join(' \u00b7 ')
    );
    var snippetText = plainSnippet(raw(result, 'text'), query);

    link.appendChild(title);
    if (contextParts.length) link.appendChild(context);
    if (snippetText) {
      link.appendChild(createElement(
        'span',
        'docsie-offline-search-result-snippet',
        snippetText
      ));
    }

    link.addEventListener('click', function(event) {
      event.preventDefault();
      event.stopPropagation();
      navigateTo(url);
    });
    item.appendChild(link);
    return item;
  }

  function setStatus(message) {
    ui.status.textContent = message;
  }

  function appendEmptyMessage(message) {
    var item = createElement('li', 'docsie-offline-search-empty', message);
    ui.results.appendChild(item);
  }

  function resultUrl(result, query) {
    var docsie = window.Docsie;
    var location = {
      shelfId: raw(result, 'doc_slug'),
      bookId: raw(result, 'book_slug'),
      articleId: raw(result, 'article_slug'),
      section: null,
      fragment: [String(query || '').toLowerCase()].concat(tokenize(query))
    };

    if (
      docsie &&
      docsie.location &&
      typeof docsie.location.linkto === 'function'
    ) {
      return docsie.location.linkto(location);
    }

    return '?doc=/' + [
      location.shelfId,
      location.bookId,
      location.articleId
    ].filter(Boolean).map(encodeURIComponent).join('/') + '/';
  }

  function navigateTo(url) {
    closeModal();
    if (
      window.Docsie &&
      window.Docsie.location &&
      typeof window.Docsie.location.go === 'function'
    ) {
      window.Docsie.location.go(url);
    } else {
      window.location.href = url;
    }
  }

  function isMacPlatform() {
    return /Mac|iPhone|iPad/.test(
      (window.navigator && window.navigator.platform) || ''
    );
  }

  function setTriggerFn(fn) {
    modalTriggerFn = fn;
  }

  function show(term) {
    if (modalTriggerFn) modalTriggerFn(true, term);
  }

  function hide() {
    if (modalTriggerFn) modalTriggerFn(false);
  }

  var OfflineSearch = {
    load: loadIndex,
    search: search,
    isLoaded: function() { return isLoaded; },
    getDocuments: function() { return documents; },
    getMeta: function() { return searchIndex ? searchIndex.meta : null; },
    setTriggerFn: setTriggerFn,
    show: show,
    hide: hide
  };

  function registerPlugin() {
    var docsie = window.Docsie;
    if (
      docsie &&
      docsie.Elements &&
      docsie.Elements.PluginBaseClass
    ) {
      searchPlugin = new docsie.Elements.PluginBaseClass('search', {
        locations: [
          {
            locationId: 'nav-plugin-bar',
            component: { type: 'offline-search' },
            order: 1
          }
        ],
        cssClasses: [
          'docsie-offline-search-plugin-container',
          'docsie-print-hidden'
        ],
        domRender: renderPlugin,
        styles: [
          STYLES,
          { style: STYLES, global: true }
        ],
        publicMethods: OfflineSearch
      });
      searchPlugin.register();
      return;
    }

    registrationAttempts += 1;
    if (registrationAttempts < 20) {
      window.setTimeout(registerPlugin, 250);
      return;
    }

    registerLegacyPlugin();
  }

  function registerLegacyPlugin() {
    var docsie = window.Docsie;
    if (!docsie || !docsie.plugins || !docsie.plugins.register) {
      console.error('Offline search: Docsie plugin API is unavailable');
      return;
    }

    docsie.plugins.register('search', function() {
      loadIndex();
      mountLegacyNavigation();
      return OfflineSearch;
    });
  }

  function mountLegacyNavigation() {
    var attempts = 0;
    function tryMount() {
      var docsie = window.Docsie;
      var root = docsie && (docsie.$el || docsie.$root);
      var navigation = root && root.querySelector
        ? root.querySelector('.docsie-nav-plugin-bar')
        : null;

      if (navigation) {
        var container = createElement(
          'div',
          'docsie-search-plugin-container docsie-offline-search-plugin-container'
        );
        navigation.appendChild(container);
        renderPlugin(null, container);
        return;
      }

      attempts += 1;
      if (attempts < 40) window.setTimeout(tryMount, 250);
    }
    tryMount();
  }

  window.DocsieOfflineSearch = OfflineSearch;
  registerPlugin();
})();
