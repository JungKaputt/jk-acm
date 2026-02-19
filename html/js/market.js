let marketInterval = null;

// Store timeout IDs for confirmation buttons to clear them if clicked
let confirmTimeouts = {}; 

window.loadMarket = function() { 
    $("#market-list").html('<div style="color:#888; text-align:center; margin-top:50px;"><i class="fas fa-circle-notch fa-spin"></i> Decrypting Market Data...</div>'); 
    
    if (marketInterval) clearInterval(marketInterval);

    $.post('https://jk-acm/getMarketItems', JSON.stringify({}), function(items) { 
        $("#market-list").empty();
        
        if(!items || items.length === 0) {
            $("#market-list").html('<div style="color:#aaa; text-align:center;">No items available via Dark Web.</div>');
            return;
        }

        let hasCooldowns = false;

        items.forEach((item, index) => { 
            let imgHtml = item.image ? 
                `<img src="nui://qb-inventory/html/images/${item.image}" alt="${item.label}" onerror="this.style.display='none'; this.nextElementSibling.style.display='block';"> <i class='fas fa-box-open fallback-icon' style='display:none'></i>` : 
                `<i class='fas fa-box-open fallback-icon'></i>`;
            
            let now = Math.floor(Date.now() / 1000);
            let isCooldown = item.cooldownExpiry > now;
            let btnHtml = '';
            let cardClass = 'market-card-modern';
            let badgeHtml = '<div class="market-badge">ILLEGAL</div>';

            if (isCooldown) {
                hasCooldowns = true;
                let timeLeft = item.cooldownExpiry - now;
                cardClass += ' cooldown-active';
                badgeHtml = '<div class="market-badge" style="color:#ff4757; border-color:#ff4757; background:rgba(255,71,87,0.1)">RESTOCKING</div>';
                
                // BUTTON LOGIC:
                // We pass the index and the fee to the new handler
                btnHtml = `
                    <button id="rush-btn-${index}" class="btn-market-buy btn-rush" 
                        data-expiry="${item.cooldownExpiry}" 
                        onclick="handleRushClick(this, ${index}, ${item.rushFee})">
                        <i class="fas fa-history"></i> <span class="timer-text">${formatTime(timeLeft)}</span>
                    </button>
                `;
            } else {
                btnHtml = `<button class="btn-market-buy" onclick="buyItem(${index})">PURCHASE</button>`;
            }

            let html = `
                <div class="${cardClass}">
                    ${badgeHtml}
                    <div class="market-img-box">${imgHtml}</div>
                    <div class="market-details">
                        <div class="market-title">${item.label}</div>
                        <div class="market-desc">${item.description || "No description provided."}</div>
                        <div class="market-footer">
                            <div class="market-price">$${item.price.toLocaleString()}</div>
                            ${btnHtml}
                        </div>
                    </div>
                </div>
            `;
            
            $("#market-list").append(html); 
        }); 

        if (hasCooldowns) {
            marketInterval = setInterval(updateMarketTimers, 1000);
        }
    }); 
}

function updateMarketTimers() {
    let now = Math.floor(Date.now() / 1000);
    let activeTimers = 0;

    $(".btn-rush").each(function() {
        // If button is in confirmation mode (has 'confirm-mode' class), do NOT update text
        if ($(this).hasClass('confirm-mode')) return;

        let expiry = parseInt($(this).data('expiry'));
        let diff = expiry - now;

        if (diff <= 0) {
            loadMarket();
        } else {
            $(this).find(".timer-text").text(formatTime(diff));
            activeTimers++;
        }
    });

    if (activeTimers === 0 && marketInterval) {
        clearInterval(marketInterval);
    }
}

function formatTime(seconds) {
    let m = Math.floor(seconds / 60);
    let s = seconds % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
}

window.buyItem = function(index) {
    $.post('https://jk-acm/buyItem', JSON.stringify({ index: index + 1, rush: false }));
}

// NEW LOGIC: Inline Confirmation
window.handleRushClick = function(btn, index, fee) {
    let $btn = $(btn);
    
    // Check if already in confirmation mode
    if ($btn.hasClass('confirm-mode')) {
        // SECOND CLICK: CONFIRMED
        $.post('https://jk-acm/buyItem', JSON.stringify({ index: index + 1, rush: true }));
        
        // Reset button immediately to prevent spam
        $btn.removeClass('confirm-mode').html('<i class="fas fa-circle-notch fa-spin"></i>');
        
        // Clear timeout
        if (confirmTimeouts[index]) clearTimeout(confirmTimeouts[index]);

    } else {
        // FIRST CLICK: SHOW CONFIRMATION
        $btn.addClass('confirm-mode');
        let originalContent = $btn.html();
        
        // Change text to show fee
        $btn.html(`<b>PAY +${fee}%?</b>`);
        
        // Auto-revert after 3 seconds if not clicked
        confirmTimeouts[index] = setTimeout(() => {
            $btn.removeClass('confirm-mode');
            // Timer text will be updated by the interval automatically
            $btn.html('<i class="fas fa-history"></i> <span class="timer-text">...</span>');
        }, 3000);
    }
}