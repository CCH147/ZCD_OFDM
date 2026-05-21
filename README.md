# 基於零點遷移與韋達定理之 ZCD-OFDM 電路與演算法

[![MATLAB Simulation](https://img.shields.io/badge/MATLAB-Simulation-blue.svg)](https://www.mathworks.com/)
[![Academic Theory](https://img.shields.io/badge/Theory-Zeros%20Relocation-orange.svg)](https://ndltd.ncl.edu.tw/)

本專案為一個端到端的**零點遷移** MATLAB 模擬系統。

---

## 核心演算法五大步驟

其運作流程如下：

### Step 1: 物理波形與代數多項式的映射 
利用歐拉公式，將連續流逝的時間 $t$ 轉換為在複數平面單位圓上旋轉的角度變數 $z$：
$$z = e^{j 2\\pi f_0 t}$$
此時，不同頻率的子載波波形 $e^{j 2\\pi k f_0 t}$ 就變成了多項式的變數次方的形式: $z^k$ ,而我們要傳送的 16-QAM 複數符碼 $a_k$ 則變成了該多項式的「係數 (Coefficients)」：
$$s(z) = a_{M+1}z^{M+1} + a_M z^M + \\dots + a_1 z^1$$

### Step 2: 零點遷移定理 
並非所有多項式方程式的根都會剛好落在單位圓上。如果根跑進圓內或圓外，在物理時間軸上就無法產生「過零點」（電壓歸零的瞬間），接收端便無法量測。
本系統引入當最高次項的係數振幅，大於等於其餘所有係數絕對值總和的一半時，所有根會被強制拉回單位圓周：
$$|a_{M+1}| \\ge \\frac{1}{2}\\sum_{k=1}^{M}|a_k|$$
在實作上，發射端（TX）會在最高頻處疊加一個能量極強的「強載波 」，強迫時域波形密集、規律地穿越 0 伏特水平線。

### Step 3: 韋達定理重建多項式 
接收端比較器精準量測到所有的過零時間 $t_k$ 後，先透過 $r_k = e^{j 2\\pi f_0 t_k}$ 反向映射回單位圓上的複數根，再利用韋達定理（根與係數的關係）將所有根相乘展開：
$$P(z) = (z - r_1)(z - r_2)(z - r_3)\\dots(z - r_{2M+2}) = 0$$
展開後得到的各項係數，即對應系統混合後的訊號特徵（MATLAB 程式碼中以 `poly()` 函數實作）。

### Step 4: 共軛倒數特性的資料提取 
由於天線只能發射純實數電壓，該多項式具備共軛倒數（鏡像對稱）的代數特性。展開後的係數陣列長相如下$`[a_5, \ a_4, \ a_3, \ a_2, \ a_1, \ DC, \ a_1^*, \ a_2^*, \ a_3^*, \ a_4^*, \ a_5^*]`$
接收端只需進行簡單的陣列切割，切出右半邊的共軛部分$`[a_1^*, \ a_2^*, \ a_3^*, \ a_4^*, \ a_5^*]`$，再執行一次共軛（`conj()`），最原始的複數資料 $a_1 \\dots a_M$ 即可完美重現。這項特性讓接收端能完全省去處理虛部（Q 訊號）的硬體電路！

---

```mermaid
graph TD
    %% 定義風格
    classDef txStyle fill:#e1f5fe,stroke:#01579b,stroke-width:2px,color:black;
    classDef chStyle fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:black;;
    classDef rxStyle fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px,color:black;

    %% 發射端流程 (使用 span 標籤將字體強制設為黑色)
    subgraph TX 發射端 TX - 訊號建構與零點遷移
        A[原始資料 16-QAM<br>複數符碼 a1 ~ a4]-->|Step 1: 分配子載波| C[強載波計算 a5<br>]  
        C -->|Step 3: 鎖定單位圓| E[多載波調變與訊號合成<br> IFFT 運算]
    end

    %% 通道流程
    E -->|發射實數時域波形 s_tx| CH[RX 接收]

    %% 接收端流程 (使用 span 標籤將字體強制設為黑色)
    subgraph RX 接收端 RX - 量測過零點與資料還原
        CH -->F[線性內插,找出穿過 0 伏特的瞬間時間 tk<br>]
        F --> |尤拉公式轉換| G[tk 時間映射複數平面單位圓上的根 rk<br>]
        G -->|單位圓上的複數根rk| H[韋達定理展開 poly<br>]
        H -->|輸出多項式 p_recon| I[利用已知 a5 校正 p_recon<br> ]
        I -->|校正後多項式 p_scaled| J[共軛倒數提取<br>切出右半邊陣列]
        J -->|共軛切片 ［a1*, a2*, a3*, a4*］| K[共軛運算 conj<br>還原原始資料]
    end

    %% 套用風格 (已移除未定義的 B, D 節點避免報錯)
    class A,C,E txStyle;
    class CH chStyle;
    class F,G,H,I,J,K rxStyle;
