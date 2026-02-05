/**
 * leaderboard.js
 * Leaderboard Logic with Smart Rendering & Real-time Updates
 */

const Leaderboard = {
    // Data
    data: [],
    selectedLevel: 1,
    totalQuestions: 0,
    socket: null,
    isFirstLoad: true,

    async init() {
        this.setupSearch();
        this.setupLevelSelect();
        this.initSocket(); // Real-time updates

        // Initial Load
        await this.loadData();
    },

    initSocket() {
        if (typeof io === 'undefined') {
            console.error("Socket.IO client not loaded");
            return;
        }

        // Connect to dynamic backend
        const socketUrl = API.BASE_URL.replace('/api', '');
        console.log("Leaderboard connecting to:", socketUrl);
        this.socket = io(socketUrl);

        this.socket.on('connect', () => {
            console.log("Leaderboard Connected to Live Updates");
        });

        // Listen for specific updates to trigger refresh
        // We can optimize to just update specific rows, but for leaderboard correctness 
        // (ranks change), fetching fresh sorted data is safer and "smart rendering" handles the visual smoothing.

        const refreshHandler = () => {
            // slightly debounce multiple rapid concurrent updates
            if (this.refreshTimer) clearTimeout(this.refreshTimer);
            this.refreshTimer = setTimeout(() => this.loadData(), 500);
        };

        this.socket.on('admin:stats_update', refreshHandler);
        this.socket.on('contest:stats_update', refreshHandler);
        this.socket.on('participant:submitted', refreshHandler);
        this.socket.on('leaderboard:update', refreshHandler);

        // Also refresh on generic contest updates (like new level active)
        this.socket.on('contest:updated', refreshHandler);
    },

    setupLevelSelect() {
        const select = document.getElementById('level-select');
        if (!select) return;

        // Populate Levels (Hardcoded 1-5 for now per original logic)
        let html = '';
        for (let i = 1; i <= 5; i++) {
            html += `<option value="${i}">Level ${i}</option>`;
        }
        select.innerHTML = html;

        // Restore prev selection if exists
        const stored = localStorage.getItem('lb_level');
        if (stored) {
            this.selectedLevel = parseInt(stored);
            select.value = this.selectedLevel;
        }

        select.addEventListener('change', (e) => {
            this.selectedLevel = parseInt(e.target.value);
            localStorage.setItem('lb_level', this.selectedLevel);
            // Reset data on level switch to force full re-render logic properly
            this.data = [];
            document.getElementById('lb-body').innerHTML = '';
            this.loadData();
        });
    },

    async loadData() {
        try {
            // If API call takes time, we don't want to freeze UI, but we also don't want to flash
            const data = await API.request(`/leaderboard/?level=${this.selectedLevel}`);

            if (data) {
                this.totalQuestions = data.total_questions || 0;
                // Store raw data
                this.data = data.leaderboard || [];
                // Render with smart Diff
                this.updateTable(document.getElementById('search-input').value);

                // Update timestamp
                const now = new Date();
                const tsEl = document.getElementById('last-updated');
                if (tsEl) tsEl.textContent = now.toLocaleTimeString();
            }
        } catch (e) {
            console.error("Leaderboard Load Error:", e);
        }
    },

    /**
     * Smart Update: Updates DOM in-place to prevent flickering
     */
    updateTable(filter = '') {
        const tbody = document.getElementById('lb-body');
        if (!tbody) return;

        // 1. Filter Data
        let displayData = [...this.data];
        if (filter) {
            const f = filter.toLowerCase();
            displayData = displayData.filter(p =>
                p.name.toLowerCase().includes(f) ||
                p.id.toLowerCase().includes(f)
            );
        }

        // 2. Map current DOM rows for quick lookup
        const existingRows = {}; // Key: participant_id -> DOM Element
        Array.from(tbody.children).forEach(row => {
            const id = row.getAttribute('data-id');
            if (id) existingRows[id] = row;
        });

        // 3. Reconcile
        // We need to maintain order. 
        // Strategy: Iterate displayData. If row exists, update content and verify position. 
        // If not, create.

        // We use a DocumentFragment for new rows if we were rebuilding, but here we want to modify in place.
        // However, re-ordering implies moving nodes.

        displayData.forEach((p, index) => {
            const domId = `row-${p.id}`; // using safe ID or data attribute
            let row = existingRows[p.id];

            // Setup content variables
            let rowClass = 'lb-row';
            if (p.rank <= 3) rowClass += ` rank-${p.rank}`;

            const rankHtml = `<div class="rank-badge">${p.rank}</div>`;
            const userHtml = `
                 <div style="font-weight: 600;">${p.name}</div>
                 <div style="font-size: 0.75rem; color: var(--text-tertiary); font-family: var(--font-mono);">${p.id}</div>
            `;
            const deptHtml = `
                <div style="font-size: 0.85rem; color: var(--text-secondary);">${p.department || '-'}</div>
                <div style="font-size: 0.75rem; color: var(--text-tertiary);">${p.college || '-'}</div>
            `;
            const scoreHtml = p.score;
            const timeHtml = p.time;
            const solvedHtml = `<span class="badge badge-success">${p.solved || 0}/${this.totalQuestions || '-'}</span>`;

            if (row) {
                // UPDATE Existing
                // Only touch DOM if changed (Micro-optimization, maybe overkill but safest against flicker)
                if (row.className !== rowClass) row.className = rowClass;

                // Update Cells directly by index to avoid full innerHTML parse
                // Cells: 0:Rank, 1:Name, 2:Dept, 3:Score, 4:Time, 5:Solved
                const cells = row.cells;
                if (cells[0].innerHTML !== rankHtml) cells[0].innerHTML = rankHtml;
                if (cells[1].innerHTML.trim() !== userHtml.trim()) cells[1].innerHTML = userHtml; // trim to avoid false pos
                if (cells[2].innerHTML.trim() !== deptHtml.trim()) cells[2].innerHTML = deptHtml;
                if (cells[3].textContent != scoreHtml) cells[3].textContent = scoreHtml; // Score is text usually or number
                if (cells[4].textContent !== timeHtml) cells[4].textContent = timeHtml;
                if (cells[5].innerHTML !== solvedHtml) cells[5].innerHTML = solvedHtml;

                // Move to correct position (appendChild moves it if already in DOM)
                // If it is not the next child, move it.
                // Current expected position is 'index'.
                if (tbody.children[index] !== row) {
                    if (index < tbody.children.length) {
                        tbody.insertBefore(row, tbody.children[index]);
                    } else {
                        tbody.appendChild(row);
                    }
                }

                // Mark as processed (remove from tracker to identify deletions)
                delete existingRows[p.id];

            } else {
                // CREATE New
                row = document.createElement('tr');
                row.className = rowClass;
                row.setAttribute('data-id', p.id);
                row.innerHTML = `
                    <td>${rankHtml}</td>
                    <td>${userHtml}</td>
                    <td>${deptHtml}</td>
                    <td class="score-cell">${scoreHtml}</td>
                    <td style="font-family: var(--font-mono);">${timeHtml}</td>
                    <td>${solvedHtml}</td>
                `;

                // Insert at correct index
                if (index < tbody.children.length) {
                    tbody.insertBefore(row, tbody.children[index]);
                } else {
                    tbody.appendChild(row);
                }
            }
        });

        // 4. Remove Stale Rows (Participants dropped out or filtered out)
        Object.values(existingRows).forEach(row => row.remove());
    },

    setupSearch() {
        const input = document.getElementById('search-input');
        if (input) {
            let debounce;
            input.addEventListener('input', (e) => {
                clearTimeout(debounce);
                debounce = setTimeout(() => {
                    this.render(e.target.value); // Use render/update logic
                }, 300);
            });
            // Also override the local filter without fetching
            input.addEventListener('keyup', (e) => {
                this.updateTable(e.target.value);
            });
        }
    },

    downloadReport() {
        window.open(`${API.BASE_URL}/leaderboard/report?level=${this.selectedLevel}&format=csv`, '_blank');
    },

    logout() {
        if (confirm('Logout from Leaderboard?')) {
            localStorage.removeItem('leader_token');
            localStorage.removeItem('leader_info');
            window.location.href = 'leader_login.html';
        }
    }
};

document.addEventListener('DOMContentLoaded', () => {
    Leaderboard.init();
});
