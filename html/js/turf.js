window.loadTurfData = function() {
    $("#turf-list").html('<div style="color:#888; text-align:center; margin-top:150px;"><i class="fas fa-satellite-dish fa-spin" style="font-size:24px; margin-bottom:15px;"></i><br>Establishing Satellite Link...</div>');
    
    $.post('https://jk-acm/getTurfData', JSON.stringify({}), function(turfs) {
        $("#turf-list").empty().removeClass().addClass("turf-grid");
        
        if(!turfs || Object.keys(turfs).length === 0) {
            $("#turf-list").html('<div style="color:#aaa; text-align:center; margin-top:50px;">No territory data found on network.</div>');
            return;
        }
        
        Object.keys(turfs).forEach(key => {
            let d = turfs[key];
            let isOwned = d.isOwned;
            let isWar = d.isContested || (d.progress > 0 && !isOwned); // Logika visual sedang perang
            
            // Tentukan Kelas CSS
            let cardClass = isOwned ? "owned" : "neutral";
            if (d.isContested) cardClass += " war-active"; // Efek Berkedip Merah
            
            // --- LOGIKA LOGO ---
            let bgDisplay = "";
            if (isOwned && d.logo && d.logo.startsWith("http")) {
                // Jika punya logo organisasi, gunakan itu
                bgDisplay = `<img src="${d.logo}" class="turf-bg-logo" onerror="this.style.display='none'">`;
            } else {
                // Fallback ke ikon standar
                let bgIcon = isOwned ? "fa-crown" : "fa-map-signs";
                bgDisplay = `<i class="fas ${bgIcon} turf-bg-icon"></i>`;
            }
            
            // Badge Status
            let badgeHtml = "";
            if (d.isContested) {
                badgeHtml = `<div class="turf-pill danger blink"><div class="status-dot red"></div> UNDER ATTACK</div>`;
            } else if (isOwned) {
                badgeHtml = `<div class="turf-pill occupied"><div class="status-dot"></div> OCCUPIED</div>`;
            } else {
                badgeHtml = `<div class="turf-pill neutral"><div class="status-dot"></div> NEUTRAL</div>`;
            }
            
            let shieldText = `<span class="shield-inactive"><i class="fas fa-lock-open"></i> Shield Offline</span>`;
            if(d.shield && d.shield > Math.floor(Date.now() / 1000)) {
                shieldText = `<span class="shield-active"><i class="fas fa-shield-virus"></i> SHIELD ACTIVE</span>`;
            }

            let ownerDisplay = isOwned ? `<span style="color:white; font-weight:bold;">${d.ownerName}</span>` : "None";

            // Progress Bar visual jika sedang direbut
            let progressHtml = '';
            if (d.progress > 0 || d.isContested) {
                let colorBar = d.isContested ? '#ff4757' : '#f1c40f';
                progressHtml = `
                    <div style="margin-top:5px;">
                        <div style="display:flex; justify-content:space-between; font-size:9px; color:${colorBar}; margin-bottom:2px;">
                            <span><i class="fas fa-crosshairs"></i> ZONE CONFLICT</span>
                            <span>${Math.floor(d.progress)}%</span>
                        </div>
                        <div class="sec-track" style="background:rgba(255,255,255,0.1);">
                            <div class="sec-fill" style="width:${d.progress}%; background:${colorBar}; box-shadow: 0 0 10px ${colorBar};"></div>
                        </div>
                    </div>
                `;
            } else {
                // Bar keamanan standar
                progressHtml = `
                    <div class="security-bar-container">
                        <div class="sec-label">
                            <span>Security Level</span>
                            <span>${isOwned ? '100%' : '0%'}</span>
                        </div>
                        <div class="sec-track">
                            <div class="sec-fill" style="width:${isOwned ? '100%' : '0%'}; background:${isOwned ? '#6c5ce7' : '#444'};"></div>
                        </div>
                    </div>
                `;
            }

            let html = `
                <div class="turf-card ${cardClass}">
                    ${bgDisplay} 
                    
                    <div class="turf-header">
                        <div class="turf-title-group">
                            <h3>${d.label}</h3>
                            <span class="turf-id">ZONE ID: ${key.toUpperCase()}</span>
                        </div>
                        ${badgeHtml}
                    </div>

                    <div class="turf-body">
                        <div class="turf-info-row">
                            <span class="turf-label">Controlled By</span>
                            <div class="turf-owner-name">
                                ${ownerDisplay}
                            </div>
                        </div>
                        ${progressHtml}
                    </div>

                    <div class="turf-footer">
                        <span><i class="fas fa-map-marker-alt"></i> Los Santos</span>
                        ${shieldText}
                    </div>
                </div>
            `;
            
            $("#turf-list").append(html);
        });
    });
}