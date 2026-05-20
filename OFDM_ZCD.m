%% ZCD_Vieta_End_to_End_Simulation.m
clear; clc; close all;

disp('======================================================');
disp('   ZCD 零點遷移與韋達還原 端到端模擬 ');
disp('======================================================');

% ========================================================
% 1. 系統參數設定
% ========================================================
f0 = 20e3;              % 基頻 (20kHz)
M = 4;                  % 資料子載波數量 (M=4)
fs = 1000 * f0 * (M+1); 
T = 1/f0;               % 1 個 OFDM 符號的時間
t = 0 : 1/fs : T - 1/fs; 

% ========================================================
% 2. TX: 發射端 (零點遷移 Zero Relocation)
% ========================================================
% 原始複數符碼 (Data Symbols)
ak_truth = [0.5+0.5i; -1+0.5i; -0.75-1i; 0.25-0.75i];

% 計算零點遷移強載波，確保所有根落在單位圓上
% 最高次項必須大於等於所有係數總和的一半
aM_carrier = (sum(abs(ak_truth)) / 2) + 1; 

fprintf('\n[TX 端] 準備發射的訊號:\n');
for k=1:M
    fprintf('a%d : %6.4f %+.4fi\n', k, real(ak_truth(k)), imag(ak_truth(k)));
end
fprintf('強載波 aM : %.4f\n', aM_carrier);

% 生成實數時域波形 (具備共軛倒數特性)
s_tx = zeros(size(t));
for k = 1:M
    % 取實部等同於加入了 a_k 與 a_k* 的共軛對稱
    s_tx = s_tx + 2 * real(ak_truth(k) * exp(1j * 2*pi * k * f0 * t));
end
% 加入最高頻的強載波 (M+1)
s_tx = s_tx + 2 * real(aM_carrier * exp(1j * 2*pi * (M+1) * f0 * t));


true_k = 0.35; % 假設空氣讓訊號振幅萎縮成原本的 35%
rx_signal = true_k * s_tx; 

% ========================================================
% 4. RX: 接收端 (尋找過零點 ZCD)
% ========================================================
% 尋找正負交替的索引值 (模擬過零點檢測器)
idx = find(rx_signal(1:end-1) .* rx_signal(2:end) < 0);

% 線性內插，精準找出穿過 0 伏特的瞬間時間 tk
y1 = rx_signal(idx); 
y2 = rx_signal(idx+1);
t1 = t(idx); 
dt = 1/fs;
tk_measured = t1 + (0 - y1) ./ (y2 - y1) * dt;

expected_roots = 2 * (M + 1);
fprintf('\n[RX 端] ZCD 偵測: 找到 %d 個過零點 (理論應為 %d 個)\n', length(tk_measured), expected_roots);

% ========================================================
% 5. 韋達定理還原 (Vieta Reconstruction)
% ========================================================
% (A) 將時間映射為複數平面單位圓上的根 (Roots)
rk_measured = exp(1j * 2*pi * f0 * tk_measured);

% (B) 韋達定理展開成多項式 (MATLAB poly函數底層即為韋達定理)
p_recon = poly(rk_measured).';

% (C) 比例校正 (Scaling)
% 這裡展現了抗衰減魔法！接收端只要除以展開後的首項，並乘回已知的 TX 強載波
scale = aM_carrier / p_recon(1); 
p_scaled = p_recon * scale;

% (D) 提取出共軛係數並還原
% 取出中間偏右的部分，這對應到共軛倒數的訊號特徵
mid = (length(p_scaled) + 1) / 2;
conj_part = p_scaled(mid+1 : mid+M);
ak_recovered = conj(conj_part).'; % 轉置並取共軛

fprintf('\n[解調結果] 透過韋達定理還原的符碼 :\n');
for k=1:M
    fprintf('a%d : %6.4f %+.4fi (誤差: %.4e)\n', ...
        k, real(ak_recovered(k)), imag(ak_recovered(k)), abs(ak_truth(k)-ak_recovered(k)));
end

% ========================================================
% 6. 視覺化繪圖
% ========================================================
figure('Name', 'ZCD & Vieta Demodulation', 'Color', 'w');

subplot(2,1,1);
plot(t, s_tx, 'b--', 'LineWidth', 1, 'DisplayName', 'TX 原始波形'); hold on;
plot(t, rx_signal, 'k-', 'LineWidth', 1.5, 'DisplayName', 'RX 衰減波形 (k=0.35)');
plot(tk_measured, zeros(size(tk_measured)), 'ro', 'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', '偵測到過零點');
title('時域波形與過零點');
xlabel('Time (s)'); ylabel('Amplitude');
legend('Location', 'best'); grid on;

subplot(2,1,2);
plot(real(ak_truth), imag(ak_truth), 'bo', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'TX 真實符碼'); hold on;
plot(real(ak_recovered), imag(ak_recovered), 'rx', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'RX 還原符碼');
title('星座圖還原結果 (IQ 平面)');
xlabel('Real Part (I)'); ylabel('Imaginary Part (Q)');
legend('Location', 'best'); grid on; axis equal;