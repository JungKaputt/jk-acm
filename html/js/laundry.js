window.loadLaundryData = function() {
    $("#avail-dirty").text("Checking...");
    
    $("#laundry-amount").val("");
    $("#res-clean").text("$0");
    $("#res-tax").text("$0");
    $("#res-fee").text("$0");

    $.post('https://jk-acm/getDirtyMoney', JSON.stringify({}), function(amt) {
        $("#avail-dirty").text("$" + amt.toLocaleString());
    });
}

window.calcLaundry = function() {
    let amt = parseInt($("#laundry-amount").val()) || 0;
    
    let pRate = 0.70;
    let oRate = 0.10;
    
    let pGet = Math.floor(amt * pRate); 
    let tGet = Math.floor(amt * oRate); 
    let fGet = amt - pGet - tGet;     
    
    $("#res-clean").text("$" + pGet.toLocaleString());
    $("#res-tax").text("$" + tGet.toLocaleString());
    $("#res-fee").text("$" + fGet.toLocaleString());
}


window.startLaundry = function() {
    let amt = $("#laundry-amount").val();
    
    if(amt > 0) {
        let btn = $(".btn-laundry-action");
        let originalText = btn.html();
        btn.html('<i class="fas fa-spinner fa-spin"></i> PROCESSING...');
        
        setTimeout(() => {
            $.post('https://jk-acm/startLaundry', JSON.stringify({ amount: amt }));
            
            closeApp('laundry');
            $.post('https://jk-acm/close', JSON.stringify({}));
            
            btn.html(originalText);
        }, 500);
    } else {
        $("#laundry-amount").addClass("error-shake");
        setTimeout(() => { $("#laundry-amount").removeClass("error-shake"); }, 300);
    }
}