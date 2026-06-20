# UVM + SystemVerilog 八股大全

> 面向数字 IC 验证岗的知识点 / 面试题汇总。三大块:**SystemVerilog 语言基础**、**UVM 方法学**、**验证思想 / 方法论**。
> 关键考点尽量用本项目(AXI-LITE2SPI UVM 平台)的真实代码行做锚点,方便对照「书上说的」和「实际怎么写」。
>
> 来源核对:CSDN「IC 验证 80 题」、VLSI Verify / ChipVerify / Verification Guide / The Art of Verification 等公认八股站,经去重 + 校对后整理。
>
> 锚点路径相对项目目录 `VMware share/AXI-LITE2SPI/`。

---

## 目录

- [第一部分 SystemVerilog 语言基础](#第一部分-systemverilog-语言基础)
- [第二部分 UVM 方法学](#第二部分-uvm-方法学)
- [第三部分 验证思想与方法论](#第三部分-验证思想与方法论)
- [附:本项目可对照的代码锚点速查](#附本项目可对照的代码锚点速查)

---

# 第一部分 SystemVerilog 语言基础

## 1.1 数据类型

### Q:`logic`、`reg`、`wire` 有什么区别?
- `wire`:线网,只能由连续赋值 / 端口驱动,不能在 `always` 里赋值。
- `reg`:变量,可在过程块赋值,但**不代表硬件寄存器**(只是「能被过程赋值」)。
- `logic`:SV 引入,本质是 4 值变量,既能被过程块赋值,也能被连续赋值/单驱动端口驱动。**唯一限制是不能多驱动**。新代码统一用 `logic`,不再纠结 reg/wire。

### Q:二值类型和四值类型?`bit` vs `logic`?
| 类型 | 取值 | 用途 |
|------|------|------|
| 四值 `logic`/`reg`/`integer` | 0/1/X/Z | 接 DUT、需要表达高阻和未知 |
| 二值 `bit`/`int`/`byte`/`longint` | 0/1 | TB 内部计数、不需要 X/Z 的场景,仿真更快 |

注意四值赋给二值,X/Z 会变成 0。`int` 32 位、`integer` 也是 32 位但四值。

### Q:数组类型有哪些?packed vs unpacked?
- **packed array**(压缩数组):`logic [7:0] data;` —— 连续存储,可整体当数,可位选。维度写在变量名**左边**。
- **unpacked array**(非压缩数组):`int mem [0:1023];` —— 各元素独立。维度写在变量名**右边**。
- **动态数组** `int q[];`:`new[n]` 分配大小,运行期可变。
- **队列** `int q[$];`:`push_back/push_front/pop_back/pop_front`、`insert/delete`、`q.size()`。本项目 scoreboard 的期望队列就是 `expected_data_q[$]`。
- **关联数组** `int aa[string];` / `aa[int]`:稀疏存储,查找用 `exists()`,适合大地址空间稀疏内存模型。

### Q:`string`、`enum`?
- `string` 是内建动态类型,有 `.len()/.substr()/.toupper()/$sformatf` 等。
- `enum` 枚举:`typedef enum logic[1:0] {IDLE, RUN, DONE} state_e;` 默认从 0 递增。方法 `.name()/.next()/.prev()/.first()/.last()`。本项目 FSM 的 5 个状态就是枚举。

## 1.2 面向对象(OOP)

### Q:`class` 和 `struct`、`module` 的区别?
class 是动态对象(句柄 + `new` 在堆上分配,可继承/多态),module 是静态硬件层次。TB 用 class,DUT 用 module。

### Q:句柄(handle)和对象的关系?浅拷贝 vs 深拷贝?
- 句柄类似指针,`obj2 = obj1` 只是两个句柄指向**同一个对象**。
- **浅拷贝**:`obj2 = new obj1;` —— 新对象,但内部的子对象句柄仍共享。
- **深拷贝**:自己写 `copy()` 逐层 new,或在 UVM 里用 `clone()`(create + do_copy)。

### Q:继承、多态、虚方法?
- `extends` 继承;`super.xxx` 调父类。
- **多态**:父类句柄指向子类对象。
- **virtual method**:父类方法加 `virtual`,通过父类句柄调用时**动态绑定**到子类的实现。这是 UVM factory override 能生效的语言基础。
- **纯虚方法** `pure virtual`:只能在 `virtual class`(抽象类)中,子类必须实现。

### Q:`static` 成员 / 方法?
全类共享一份。常见:静态计数器统计创建了多少对象;`static function` 不依赖实例即可调用(如单例 `get()`)。

## 1.3 约束随机(Constrained Random)

### Q:`rand` 和 `randc` 区别?
- `rand`:每次随机,可重复。
- `randc`:循环随机(random-cyclic),一个周期内不重复,遍历完所有值才重来。代价高,只对小位宽用。

### Q:`randomize()` 的返回值?调用流程?
返回 1 成功 / 0 失败(约束冲突)。流程:`pre_randomize()` → 求解器解约束 → 赋值 → `post_randomize()`。

### Q:常用约束写法?
```systemverilog
rand bit [7:0] len;
rand bit [1:0] mode;
constraint c_len   { len inside {[1:64]}; }
constraint c_dist  { mode dist {0:=70, [1:3]:=10}; }   // 权重分布
constraint c_order { solve mode before len; }          // 求解顺序,影响分布
constraint c_soft  { soft len == 8; }                  // 软约束,可被覆盖
```
- `inside`、`dist`(`:=` 每值权重 / `:/` 区间总权重)、`solve...before`(只改概率分布,不改解空间)、`soft`(软约束,优先级低,冲突时让步)。
- 内联约束:`item.randomize() with { len == 16; }`。
- 关闭约束:`item.c_len.constraint_mode(0);`;关闭某变量随机:`item.len.rand_mode(0);`。

### Q:本项目哪里用了约束随机?
`spi_random_test` 跑 80 帧约束随机(mode × wlen × speed × data 交叉),配合 covergroup 收敛功能覆盖率。见 [spi_random_test.sv](VMware share/AXI-LITE2SPI/UVMTB/test/spi_random_test.sv)。

## 1.4 进程与同步

### Q:`fork...join / join_any / join_none` 区别?
| 形式 | 行为 |
|------|------|
| `join` | 等**所有**子进程结束 |
| `join_any` | 等**任意一个**结束就继续(其余继续跑) |
| `join_none` | **不等**,立即继续,子进程后台跑 |

本项目 driver 的 `run_phase` 用 `fork ... join_none` 同时起「驱动总线」和「监视复位」两个常驻线程:见 [axi_driver.sv:24](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv)。并发模式里更进一步用 `join_none` 起「写通道 / 读通道 / dispatch」三线程:[axi_driver.sv:56](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv)。

### Q:`disable fork`、`wait fork`?
- `wait fork`:阻塞直到当前作用域内所有 fork 出去的进程结束。
- `disable fork`:杀掉当前作用域 fork 出来的所有子进程。
- 典型「超时机制」:`fork ...干活...; ...超时...; join_any  disable fork;`。
- 本项目 SPI monitor 用 `fork`+`disable` 实现「reset 时中止当前帧采样」。

### Q:`mailbox` 和 `semaphore`?
- `mailbox`:进程间传消息的 FIFO,`put/get/peek/try_get`,可有界/无界、可参数化类型。本项目并发 driver 用 `mailbox #(axi_seq_item)` 做读写双通道队列:[axi_driver.sv:54](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv)。
- `semaphore`:计数信号量,`new(n)` / `get(k)` / `put(k)`,做资源互斥 / 限流。

### Q:`event`?
事件同步。`->e` 触发,`@(e)` 等待,`wait(e.triggered)` 避免错过同拍触发。

## 1.5 接口与时序

### Q:`interface`、`modport`、`clocking block` 各干什么?
- `interface`:把一组信号打包,DUT 和 TB 共用,减少端口连线。本项目 [axi_interface.sv](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_interface.sv)、[spi_interface.sv](VMware share/AXI-LITE2SPI/UVMTB/spi/spi_interface.sv)。
- `modport`:规定方向(master/slave/monitor 视角各自的 in/out)。
- `clocking block`:把信号采样 / 驱动同步到某时钟沿,带 input/output skew,**消除竞争**(race),让 TB 在确定的时刻采到稳定值。

### Q:`virtual interface` 为什么需要?
class 是动态对象,不能直接例化静态 interface。`virtual interface` 是指向实际 interface 实例的句柄,让 driver/monitor 这些 class 能访问 DUT 引脚。本项目 driver 里 `virtual axi_interface vif;`,通过 config_db 从 config 对象拿到:[axi_driver.sv:6](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv) + [:18](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv)。

### Q:`task` 和 `function` 区别?
| | task | function |
|--|------|----------|
| 耗时 | 可含 `#`、`@`、`wait` | **不可耗时**(0 时间) |
| 返回 | 无返回值(可 output/ref) | 必须有返回值(void 除外) |
| 调用 | 只能在过程块 | 可在表达式 |

UVM 里 `build_phase` 等是 function(不耗时),`run_phase` 是 task(耗时)。

## 1.6 覆盖率(语言层)

### Q:`covergroup` / `coverpoint` / `cross` / `bins`?
```systemverilog
covergroup cg_spi_frame @(posedge sample);
  cp_mode : coverpoint mode { bins m[] = {[0:3]}; }
  cp_wlen : coverpoint wlen { bins w[] = {[0:3]}; }
  x_mw    : cross cp_mode, cp_wlen;   // 16 个 cross bin
endgroup
```
- `covergroup` 定义采样模板,需 `new()` 例化并 `.sample()`(或事件触发)。
- `bins` 分桶:`bins a = {0}` / `bins b[] = {[1:3]}`(自动拆) / `illegal_bins` / `ignore_bins` / 转移 `bins t = (0=>1=>2)`。
- `cross` 交叉覆盖。本项目 [tb_coverage.sv](VMware share/AXI-LITE2SPI/UVMTB/coverage/tb_coverage.sv) 的 `cg_spi_frame` 做 mode×wlen / mode×speed 交叉,已达 100%。
- 常用 option:`option.per_instance`、`option.at_least`、`option.weight`、`option.goal`。

## 1.7 SystemVerilog 断言(SVA)

### Q:immediate 和 concurrent assertion 区别?
- **immediate**:`assert(expr) else ...;` 过程块内,0 时刻立即判断,组合逻辑式检查。
- **concurrent**:`assert property (@(posedge clk) ...);` 基于时钟沿采样,可跨多个周期描述时序。

### Q:蕴含 `|->` 和 `|=>`?
- `|->`:**同周期**蕴含,前件成立的那拍就检查后件。
- `|=>`:**下一周期**蕴含,等价 `|-> ##1`。

### Q:常用采样函数?
`$rose / $fell / $stable / $past(expr, n) / $onehot / $countones`。例:`@(posedge clk) $rose(start) |-> ##[1:5] busy;`。

### Q:本项目 SVA 怎么用的?
- CS→SCK 延迟检查 + cover:[spi_cs_sck_sva.sv](VMware share/AXI-LITE2SPI/UVMTB/spi/spi_cs_sck_sva.sv)(用 `generate` 起 3 档 EXP=2/4/8)。
- SCK 速度 4 档:[spi_sck_speed_sva.sv](VMware share/AXI-LITE2SPI/UVMTB/spi/spi_sck_speed_sva.sv)。
- 复位 SVA:[spi_reset_sva.sv](VMware share/AXI-LITE2SPI/UVMTB/spi/spi_reset_sva.sv)、[axi_reset_sva.sv](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_reset_sva.sv)。
- 关键技巧:`AXI_RESET_RELEASE_CHK` 加前提 `!AWVALID && !WVALID && !ARVALID`,避免悬挂事务误报(见 CLAUDE.md 修复记录)。

---

# 第二部分 UVM 方法学

## 2.1 总览

### Q:UVM 是什么?为什么要用?
UVM(Universal Verification Methodology)是建立在 SystemVerilog 之上的标准化验证方法学和基类库(IEEE 1800.2)。好处:
1. **可复用**:agent / sequence / env 可跨项目移植。
2. **标准化**:phase、factory、config_db、TLM 统一了团队写法。
3. **激励与平台解耦**:sequence 写激励、组件搭平台,改用例不动平台。
4. **仿真器无关**:VCS/Questa/Xcelium 都支持。

### Q:UVM 类层次(谁继承谁)?
```
uvm_void
└── uvm_object              ← 动态数据(transaction/config/sequence)
    ├── uvm_transaction
    │   └── uvm_sequence_item   ← 事务对象
    │       └── uvm_sequence    ← 激励序列
    └── uvm_report_object
        └── uvm_component   ← 有层次、有 phase(driver/monitor/agent/env/test...)
```
- `uvm_object`:无层次、无 phase,生命周期由用户控制(transaction、config)。
- `uvm_component`:有 `parent`、有固定层次路径、参与 phase 机制,仿真期间长期存在。

### Q:`uvm_transaction` 和 `uvm_sequence_item` 区别?
sequence_item 继承自 transaction,额外带 sequence 相关字段(sequencer 句柄、序列 ID 等),实际激励都用 sequence_item。本项目 [axi_seq_item.sv](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_seq_item.sv)。

## 2.2 Factory(工厂)

### Q:factory 解决什么问题?`create` 和 `new` 区别?
- `new`:直接构造一个固定类型对象,**无法被替换**。
- `create`(`type_id::create`):向 factory 申请对象,**可以在运行前被 override 成派生类型**,不改平台结构就能换实现/换激励。
- 前提:类要用 `` `uvm_component_utils `` / `` `uvm_object_utils `` 注册。本项目每个组件顶部都有,如 [axi_driver.sv:3](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv)。

### Q:type override 和 instance override?
```systemverilog
set_type_override_by_type(axi_driver::get_type(), axi_driver_err::get_type());     // 全局换类型
set_inst_override_by_type("env.axi_agt.axi_drv", base::get_type(), derived::get_type()); // 指定实例换
```
instance override 优先级高于 type override。命令行也能 `+uvm_set_type_override=base,derived`。

### Q:`copy` vs `clone`?
- `copy(rhs)`:把 rhs 内容拷到已存在对象(内部调 `do_copy`)。
- `clone()`:`create` 一个新对象 + `copy`,返回 `uvm_object` 句柄(需 `$cast`)。clone 走 factory,所以也能被 override。

## 2.3 config_db(配置数据库)

### Q:`uvm_config_db` 怎么用?set/get?
```systemverilog
uvm_config_db#(T)::set(context, "inst_path", "field_name", value);   // 存
uvm_config_db#(T)::get(context, "inst_path", "field_name", var);     // 取,返回 bit 表示是否命中
```
- 作用域路径 `{context.get_full_name(), ".", inst_path}`,支持通配符 `*`。
- 本项目典型链路:`tb_top` 把 vif set 到 `uvm_test_top` → test_base `get` vif([test_base.sv:21](VMware share/AXI-LITE2SPI/UVMTB/test/test_base.sv))→ 把 config set 给 env([test_base.sv:28](VMware share/AXI-LITE2SPI/UVMTB/test/test_base.sv))→ env set 给 agent([tb_environment.sv:23](VMware share/AXI-LITE2SPI/UVMTB/env/tb_environment.sv))→ agent set 给 driver([axi_agent.sv:28](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_agent.sv))→ driver `get`([axi_driver.sv:15](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv))。

### Q:config_db 和 resource_db 区别?
两者底层是同一套 `uvm_resource_db`。`config_db` 多了层次路径语义和 `set/get` 时的层次匹配优先级(越靠近 root 的 set 优先级越高,且后 set 覆盖先 set);`resource_db` 是更底层、无层次语义的纯资源池。日常配置用 config_db。

## 2.4 Phase(相位机制)

### Q:为什么要 phase?有哪些 phase?
解决「所有组件何时建、何时连、何时跑」的同步问题。

**function phase(不耗时,9 个,按序):**
`build` → `connect` → `end_of_elaboration` → `start_of_simulation` → (run) → `extract` → `check` → `report` → `final`。

**run_phase 可拆成 12 个 task runtime phase(耗时,UVM 自带):**
`pre_reset → reset → post_reset → pre_configure → configure → post_configure → pre_main → main → post_main → pre_shutdown → shutdown → post_shutdown`。`run_phase` 与这 12 个并行跑。

### Q:哪些 phase 自顶向下,哪些自底向上?
- `build_phase`:**top-down**(先父后子,父必须先建好才能 set config 给子)。本项目 test_base → env → agent → driver 逐层 build,正是这个顺序。
- `connect_phase`:**bottom-up**(子先连好,父再连)。见 [axi_agent.sv:38](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_agent.sv) driver↔sequencer 的连接,[tb_environment.sv:45](VMware share/AXI-LITE2SPI/UVMTB/env/tb_environment.sv) monitor→scoreboard。
- 其余 phase 一般 bottom-up。

### Q:哪些 phase 是 function、哪些是 task?为什么?
function phase 不耗仿真时间(0 时刻完成搭建/检查),所以是 function;run/runtime phase 要等时钟、等事务,必须是 task。

### Q:为什么 phase 里要写 `super.xxx_phase(phase)`?
调用基类 `uvm_component` 的 phase 实现(尤其 field automation、内部记账)。本项目每个 phase 第一行都是 `super.build_phase(phase);`。

### Q:`run_test()` 干了什么?
创建 factory、解析命令行 `+UVM_TESTNAME`、`create` 出对应 test、`uvm_top` 例化层次、依次推进所有 phase。本项目在 `tb_top` 调用,test 名通过 Makefile `TEST=xxx` 传 `+UVM_TESTNAME`。

## 2.5 Objection(结束机制)

### Q:objection 是什么?如何控制仿真结束?
run phase 默认会一直跑。组件在开始干活时 `phase.raise_objection(this)`,干完 `phase.drop_objection(this)`;当某 phase 所有 objection 都 drop,该 phase 结束。通常在 **sequence / test** 里 raise/drop,而不在 driver。

### Q:`phase_ready_to_end`?drain time?
phase 准备结束时回调,可用来「再等一会儿」(`phase.raise_objection` 续命)或设置 drain time(`set_drain_time`),保证尾部事务跑完。

### Q:除了 objection,还有哪些结束方式?
`$finish`(硬停,不推荐)、`uvm_fatal`(致命错误终止)、global timeout(`uvm_top.set_timeout`)。

## 2.6 TLM(事务级通信)

### Q:port / export / imp 区别?
- **port**:发起方,声明「我要调用某接口方法」。
- **export**:转发,把请求往下层传。
- **imp**(implementation):**实现方**,真正实现接口方法(如 `write()`)。
- 连接方向:`initiator.port.connect(target.export/imp)`。

### Q:`analysis_port` 和普通 port 区别?
- 普通 port(`uvm_blocking_put_port` 等)一对一,可阻塞,有反压。
- **analysis_port**:一对多广播,`write()` 非阻塞,无反压,monitor 发数据给多个订阅者(scoreboard + coverage)用它。本项目 [axi_agent.sv:11](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_agent.sv) 声明 `uvm_analysis_port`,在 [tb_environment.sv:45-52](VMware share/AXI-LITE2SPI/UVMTB/env/tb_environment.sv) 一个 monitor 同时连 scoreboard 和 coverage。
- 订阅端用 `uvm_analysis_imp` 或 `uvm_subscriber`,实现 `write()`。

### Q:`uvm_tlm_fifo`、`uvm_tlm_analysis_fifo`?
带缓冲的 TLM 通道,生产/消费速率不一致时缓冲事务;analysis_fifo 自带 analysis_export 可直接接 monitor。

## 2.7 组件与 agent

### Q:UVM 标准组件及职责?
| 组件 | 职责 |
|------|------|
| `uvm_driver` | 从 sequencer 取 item,按协议时序驱动 DUT 引脚 |
| `uvm_monitor` | 采集 DUT 引脚,还原成 transaction,经 analysis_port 广播 |
| `uvm_sequencer` | 仲裁/调度 sequence,把 item 递给 driver |
| `uvm_agent` | 封装 driver+monitor+sequencer(active)或仅 monitor(passive) |
| `uvm_scoreboard` | 收期望与实际,比对判正确性 |
| `uvm_subscriber` | 订阅 analysis 流,常做 coverage |
| `uvm_env` | 组合多个 agent + scoreboard + coverage |
| `uvm_test` | 顶层,配 config、选 sequence |

### Q:active 和 passive agent?
- **active**:有 driver+sequencer+monitor,**驱动**总线。本项目 AXI agent 是 active(主动发 AXI 事务):[axi_agent.sv](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_agent.sv)。
- **passive**:只有 monitor,**只听不驱动**。本项目 SPI agent 是 passive(只监听 SPI 输出):[spi_monitor.sv](VMware share/AXI-LITE2SPI/UVMTB/spi/spi_monitor.sv) 直接由 env 例化。
- 切换靠 `is_active`(`UVM_ACTIVE`/`UVM_PASSIVE`),在 build_phase 决定建不建 driver/sequencer。

## 2.8 Sequence / Sequencer / Driver 握手

### Q:三者怎么通信?
sequence 在 sequencer 上跑 `body()`,通过 `start_item/finish_item`(或 `` `uvm_do ``)把 item 经 sequencer 递给 driver;driver 用 `seq_item_port` 取 item。连接在 agent 的 connect_phase:`driver.seq_item_port.connect(sequencer.seq_item_export)`(本项目 [axi_agent.sv:38](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_agent.sv))。

### Q:driver 侧的握手 API?
| API | 行为 |
|-----|------|
| `get_next_item(req)` | 阻塞取下一个 item(不弹出) |
| `try_next_item(req)` | 非阻塞,没有就返回 null |
| `item_done()` | 通知 sequencer 当前 item 处理完,放行下一个 |
| `get(req)` | = get_next_item + item_done(一步) |
| `put(rsp)` | 回传 response |

本项目标准用法 [axi_driver.sv:37-44](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv):
```systemverilog
seq_item_port.get_next_item(item);
if (item.write) drive_write(item); else drive_read(item);
seq_item_port.item_done();
```
并发模式里把 `item_done` 提前到 dispatch 之后,实现「放行下一笔、读写后台并行」:[axi_driver.sv:70-76](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv)。

### Q:`start_item/finish_item` 和 `` `uvm_do `` 系列?
- 手写:`start_item(req); assert(req.randomize()); finish_item(req);`。
- 宏:`` `uvm_do(req) ``(create+rand+send)、`` `uvm_do_with(req,{...}) ``(带内联约束)、`` `uvm_rand_send(req) ``(已 create,只随机+发)、`` `uvm_send(req) ``(只发)。

### Q:sequence 怎么启动?`start()` 干了什么?
`seq.start(sequencer)`:把 sequencer 句柄赋给 `m_sequencer`,调用 `pre_body → body → post_body`,body 结束 start 返回。本项目 sequence 用法见 CLAUDE.md 的 `axi_spi_cfg_seq` 示例,定义在 [axi_sequence_lib.sv](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_sequence_lib.sv)。

### Q:`m_sequencer` 和 `p_sequencer` 区别?
- `m_sequencer`:基类 `uvm_sequencer_base` 句柄,所有 sequence 自带,指向运行它的 sequencer。
- `p_sequencer`:用户用 `` `uvm_declare_p_sequencer `` 声明的**具体类型** sequencer 句柄,能访问自定义成员(如 virtual sequencer 里的子 sequencer 句柄)。

## 2.9 Virtual sequence / sequencer

### Q:virtual sequence 解决什么?
多个 agent(多个 sequencer)需要协调时序时,用一个 **virtual sequence** 在 **virtual sequencer** 上跑,virtual sequencer 持有各子 sequencer 的句柄,统一编排多通道激励。virtual sequence 自己不产生 item,只调度子 sequence(`seq.start(p_sequencer.sub_sqr)`)。

### Q:`lock` / `grab` / 仲裁?
- 多个 sequence 抢同一 sequencer 时,sequencer 按仲裁策略(`SEQ_ARB_FIFO`/`WEIGHTED`/`RANDOM`...)发 item。
- `lock()`:排队独占,直到前面的让出。
- `grab()`:插队独占(优先级最高)。
- 用完 `unlock()`/`ungrab()`。

## 2.10 RAL(寄存器抽象层)

### Q:RAL 是什么?组成?
对 DUT 寄存器建模的抽象层,让用例用 `reg.write/read` 操作寄存器而非手搓总线时序。组成:
- **reg_block / reg / field**:寄存器模型(本项目 [axi_spi_reg_block.sv](VMware share/AXI-LITE2SPI/UVMTB/ral/axi_spi_reg_block.sv),10 个 reg = 8 WO + 2 RO)。
- **adapter**:reg 操作 ↔ 总线 seq_item 的转换(本项目 [axi_spi_reg_adapter.sv](VMware share/AXI-LITE2SPI/UVMTB/ral/axi_spi_reg_adapter.sv) 的 `reg2bus/bus2reg`)。
- **predictor**:从 monitor 流自动更新 mirror。
- **map**:地址映射。

### Q:frontdoor 和 backdoor 访问?
- **frontdoor**:走真实总线时序(经 adapter + sequencer),验证总线访问路径。
- **backdoor**:用 `uvm_hdl_*` / `peek/poke` **直接读写 DUT 内部信号**,0 时间,不经总线,用于快速初始化或绕过总线检查。本项目 [ral_test.sv](VMware share/AXI-LITE2SPI/UVMTB/test/ral_test.sv) 两者都冒烟。

### Q:mirror / desired / actual?`predict` / `mirror` / `update`?
- **desired**:期望写进去的值;**mirrored**:模型认为 DUT 当前的值;**actual**:DUT 真实值。
- `read/write`:读写(更新 mirror)。`peek/poke`:backdoor 读/写。
- `mirror()`:读 DUT 并和 mirror 比对。`predict()`:不访问硬件,直接设 mirror。`update()`:把 desired 与 mirror 不一致的寄存器写下去。

## 2.11 报告与其它

### Q:`uvm_info/warning/error/fatal`、verbosity、severity?
- severity(严重度):`UVM_INFO / UVM_WARNING / UVM_ERROR / UVM_FATAL`。
- verbosity(详细度):`UVM_NONE/LOW/MEDIUM/HIGH/FULL/DEBUG`,`uvm_info(ID, MSG, VERB)` 只在当前阈值 ≥ VERB 时打印。命令行 `+UVM_VERBOSITY=UVM_HIGH`。
- 本项目 PASS/FAIL 判据:Makefile 用 grep `UVM_ERROR ... 0` && `UVM_FATAL ... 0`。

### Q:callback 机制?
`uvm_callback` 在不改组件源码的前提下注入行为(如注错、改激励)。比 factory override 更细粒度(方法级)。

### Q:UVM 怎么打印拓扑?
`uvm_top.print_topology()`,本项目在 [test_base.sv:34](VMware share/AXI-LITE2SPI/UVMTB/test/test_base.sv) 的 `end_of_elaboration_phase` 调用。

---

# 第三部分 验证思想与方法论

## 3.1 验证流程

### Q:一个完整验证流程?
1. **读 spec** → 提取功能点。
2. **写 Verification Plan(VPlan)** → 列测试项 + 覆盖项 + 检查项。本项目 CLAUDE.md 的「测试清单(VPlan)」就是这个。
3. **搭平台**(UVM env)。
4. **写用例 + sequence**(定向 + 随机)。
5. **跑仿真 + debug**。
6. **收覆盖率**,补洞。
7. **回归 + 签核**。

### Q:定向测试 vs 约束随机?
- **定向(directed)**:精确命中特定场景(corner case、协议握手三时序),可控、易 debug。本项目 `axi_handshake_test` 就是定向。
- **约束随机(CRT)**:大空间自动探索,配合覆盖率收敛,发现意料外 bug。本项目 `spi_random_test`(80 帧)。
- 实战:先定向打通通路 + 关键 corner,再随机扫面。

## 3.2 覆盖率

### Q:覆盖率分几类?
| 类型 | 子项 | 谁产生 |
|------|------|--------|
| **代码覆盖率** | line / toggle / FSM / condition / branch | 工具自动(无脑度量「跑到没」) |
| **功能覆盖率** | covergroup / coverpoint / cross | 人写(度量「测到没」) |
| **断言覆盖率** | assertion / cover property | SVA |

本项目现状(CLAUDE.md):功能覆盖率 GROUP 100%、断言 100%、DUT 代码 line 90%/cond 63%/branch 90% + 7 条 waiver。

### Q:代码覆盖率 100% 是否等于验证完整?
**不等于**。代码覆盖率只说明「代码被执行过」,不说明「功能对不对、组合对不对」。功能覆盖率才表达「spec 的功能点是否被测到」。两者互补,缺一不可。

### Q:什么是覆盖率驱动验证(CDV)?
以覆盖率为反馈闭环:随机激励 → 收覆盖率 → 看哪些 bin 没命中 → 调约束/加定向 → 再跑,直到收敛。

### Q:覆盖率有洞怎么办?waiver?
- 先判断是「测不到」还是「设计本就不该有」。
- 合理的不可达项写 **waiver**(豁免)并说明理由。本项目 7 条 waiver(W1–W7,如「配置寄存器 write-only,读回返回 0 是设计意图」)就是典型。

## 3.3 自检与比对

### Q:scoreboard 怎么工作?
收两路数据:**期望**(从激励侧/参考模型算出)和**实际**(从 monitor 采),逐笔比对。本项目 [tb_scoreboard.sv](VMware share/AXI-LITE2SPI/UVMTB/scoreboard/tb_scoreboard.sv):AXI monitor 写 slv_reg8 → 按 word_len mask 后 push `expected_data_q`;SPI monitor 采到 MOSI → pop 比对。

### Q:顺序 vs 乱序 scoreboard?
- **顺序(in-order)**:FIFO,先进先比。本项目 SPI 帧严格顺序,用队列。
- **乱序(out-of-order)**:用关联数组/ID 匹配,适合带 tag 的乱序返回协议。

### Q:reference model(参考模型)?
独立实现 DUT 功能(C/SV),scoreboard 拿它的输出当期望。简单 DUT 可省(直接从激励推期望,本项目即如此)。

## 3.4 复位、并发等 corner

### Q:复位测试要点?
传输中复位、复位释放后能否恢复、复位期间信号是否清零。本项目:`reset_mid_test` 传输中复位(monitor reset 感知 + scoreboard flush),`reset_sva_test` 多场景复位 SVA。driver 的复位清信号见 [axi_driver.sv:135](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv)。

### Q:outstanding / 读写并发怎么验?
先从 RTL 判断 DUT 是否支持(本项目 DUT 写/读通道都是 depth=1,不支持 outstanding,但读写可并发)。`axi_concurrent_test` 用 driver 的 `concurrent_mode` 把读写分流到双线程验证并发不死锁:[axi_driver.sv:53](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv)。

## 3.5 回归与签核

### Q:回归(regression)?
所有用例批量自动跑 + 收覆盖率,确认无回归 bug。本项目 `make all_test` 跑 21 个 test + URG 覆盖率。

### Q:签核(signoff)条件?
功能覆盖率达标、代码覆盖率达标(含 waiver)、断言全过、回归 0 fail、bug 收敛(bug 曲线趋零)。本项目当前 21/21 全 PASS、功能/断言 100%。

### Q:debug 思路?
1. 看 `regression_summary.txt` 定位哪个 test fail(本项目习惯:先读 summary 不读完整 log)。
2. 看 UVM_ERROR 的 ID/message → 定位是 scoreboard 比对 fail 还是 assertion fail。
3. 对应到激励 → DUT 行为 → 用 FSDB 波形(Verdi)看时序。
4. 缩小到最小复现用例。

---

# 附:本项目可对照的代码锚点速查

| 八股考点 | 项目文件:行 |
|----------|-------------|
| `fork...join_none` 多线程 | [axi_driver.sv:24](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv) |
| `mailbox` 通道 | [axi_driver.sv:54](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv) |
| driver 握手 get_next_item/item_done | [axi_driver.sv:37](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv) |
| virtual interface + config_db get | [axi_driver.sv:15](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv) |
| factory 注册 `uvm_component_utils` | [axi_driver.sv:3](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_driver.sv) |
| `type_id::create` | [test_base.sv:16](VMware share/AXI-LITE2SPI/UVMTB/test/test_base.sv) |
| config_db set/get 链路 | [test_base.sv:21](VMware share/AXI-LITE2SPI/UVMTB/test/test_base.sv)、[tb_environment.sv:23](VMware share/AXI-LITE2SPI/UVMTB/env/tb_environment.sv)、[axi_agent.sv:28](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_agent.sv) |
| build_phase top-down | [test_base.sv:12](VMware share/AXI-LITE2SPI/UVMTB/test/test_base.sv) |
| connect_phase bottom-up + analysis port | [axi_agent.sv:35](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_agent.sv)、[tb_environment.sv:41](VMware share/AXI-LITE2SPI/UVMTB/env/tb_environment.sv) |
| analysis_port 一对多 | [tb_environment.sv:45](VMware share/AXI-LITE2SPI/UVMTB/env/tb_environment.sv) |
| active/passive agent | [axi_agent.sv](VMware share/AXI-LITE2SPI/UVMTB/axi/axi_agent.sv) / [spi_monitor.sv](VMware share/AXI-LITE2SPI/UVMTB/spi/spi_monitor.sv) |
| scoreboard 比对 | [tb_scoreboard.sv](VMware share/AXI-LITE2SPI/UVMTB/scoreboard/tb_scoreboard.sv) |
| covergroup/cross | [tb_coverage.sv](VMware share/AXI-LITE2SPI/UVMTB/coverage/tb_coverage.sv) |
| SVA(蕴含/采样/generate) | [spi_cs_sck_sva.sv](VMware share/AXI-LITE2SPI/UVMTB/spi/spi_cs_sck_sva.sv)、[spi_sck_speed_sva.sv](VMware share/AXI-LITE2SPI/UVMTB/spi/spi_sck_speed_sva.sv) |
| RAL 模型/adapter/前后门 | [axi_spi_reg_block.sv](VMware share/AXI-LITE2SPI/UVMTB/ral/axi_spi_reg_block.sv)、[axi_spi_reg_adapter.sv](VMware share/AXI-LITE2SPI/UVMTB/ral/axi_spi_reg_adapter.sv)、[ral_test.sv](VMware share/AXI-LITE2SPI/UVMTB/test/ral_test.sv) |
| 约束随机回归 | [spi_random_test.sv](VMware share/AXI-LITE2SPI/UVMTB/test/spi_random_test.sv) |
| 复位 corner | [reset_mid_test.sv](VMware share/AXI-LITE2SPI/UVMTB/test/reset_mid_test.sv)、[reset_sva_test.sv](VMware share/AXI-LITE2SPI/UVMTB/test/reset_sva_test.sv) |

---

## 主要参考来源

- [CSDN — IC 验证 80 题](https://blog.csdn.net/seuer0420/article/details/132506945)
- [VLSI Verify — UVM Interview Questions](https://vlsiverify.com/interview-questions/uvm-interview-questions/)
- [ChipVerify — UVM Interview Questions](https://www.chipverify.com/uvm/uvm-interview-questions-set-2)
- [Verification Guide — UVM Interview Questions](https://verificationguide.com/uvm/uvm-interview-questions/)
- [The Art of Verification — UVM Interview Questions](https://theartofverification.com/uvm-interview-questions/)
- 标准:IEEE 1800.2(UVM)、IEEE 1800(SystemVerilog)
