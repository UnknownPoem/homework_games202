# 随便写点东西，防忘

## 作业0
据网上的说法，index.html里改个东西，防止模型加载有问题。

## 作业1
普通shadowmap中，值得注意的点是，要构建了一个正交的矩阵，这意味着计算出来的是平行光下的阴影。
考虑加一个bias，此处使用的是这个公式：bias = max(base_bias * (1.0 - cos(normal, light_dir)), min_bias)

PCF中，值得注意的是，我们随机生成的采样点区域是[-1, 1]，需要再设置一个filterRange
另外就是，uv的偏移是要除以Shadowmap_Size的。

PCSS中，相比PCF，也就是通过遮挡物的平均深度，去确定了一个更合适的filterRange.
重点是用随机采样方式，计算出uv附近的平均深度，再用平均深度确定filterRange范围。

## 作业2
PRT(Precomputed Radiance Transfer)

### C++部分：nori
这部分主要是预计算光照函数与传输函数的球谐系数

#### 编译报错
报错`<lambda_9ed74708f63acbd4deb1a7dc36ea3ac3>::operator()`
这似乎是因为中文字符吞换行符(https://games-cn.org/forums/topic/guanyuzuoye2kaitoubianyidekunhuo/)
在cmakelist.txt 112行，添加`target_compile_options(nori PUBLIC /utf-8) # MSVC unicode support`

编译报错 `error C2039: "binary_function": 不是 "std" 的成员`
这是因为C++17中删掉了它。最简单的改法是，在该文件中加`#include <functional>`

#### 做预计算
##### 从源头理解一下先
PRT，基于设定：每个物体不会自发光、光源无限远
光照 = 光照函数 * 可见性函数 * 几何函数
其中，可见性函数与几何函数合并称为传输函数

球谐函数有一个比较牛逼的特性是：函数乘积的积分等于球谐系数向量的点积。
这意味着，我们把上面的光照函数和传输函数，分别预计算，用球谐系数的形式存储，等到计算时再拿出来，即可得到光照着色结果。

这是大致的工作流程
光照项：（包含直接光，间接光）
1. 环境光采样，从环境光图片中采样光照数据，把每个像素的光照转换到立体角上。
1. 球谐投影，把采样得到的光照数据投影到球谐函数基上。
1. 系数存储。把计算得到的球谐系数存起来，以便在实时渲染时用。
传输项：（传输，阴影，内部反射，次表面散射，焦散，支持任何传输。
1. 场景采样：在场景中采样一系列点，计算这些点的传输函数。传输函数描述了从每个点到场景中其他点的光线传播过程。
1. 球谐投影：把传输函数投影到球谐函数基上。这通常涉及对传输函数进行积分，并计算其与每个球谐基函数的点积。
1. 系数存储。

对于光照项，公式是：SH_Coeffiecent = Lenv(wi) * SW(w0) * delta_w.
对于传输项，
应该从光照方程开始: 
L(x, w0) = Sum_surface[ fr(x, wi, w0) * Li(x, wi) * H(x, wi) * delta_wi * visibility ] // Sum表示曲面积分
其中，fr项是BRDF项，由于是表面处处相等的漫反射表面，因此fr = Phi / Pi.
Li且不论，这是光照项存的东西。
H项即为cos项，H = cos(wi, Nx)，也即为dot(wi, Nx)
visibility 在本作业中，会以有无shadowed的形式来算（应该是自阴影）

##### 作业框架

关于补充`PrecomputeCubemapSH`函数
这个函数用于计算光照项。
作业框架已经帮忙写到了具体某一像素（也即cubemap采样方向）的循环，因此，只需要我们针对该采样方向，计算并填入待计算的SHOrder阶的每一个系数即可。这可以通过双重循环来做
```
for (int l = 0; l <= SHOrder; ++l) {
    for (int m = -l; m <= l; ++m) {
        // 计算每一个系数
    }
}
```
针对每一个系数，公式是：SH_Coeffiecent = Lenv(wi) * SW(w0) * delta_w.
其中，Lenv(wi)可从image采样得出。SW(w0)由采样方向确定和具体哪一个系数，有固定公式，可参考`sh::EvalSH`函数。delta_w是单位面积（定积分的微元），可参考`CalcArea`函数.
辅助函数作业框架均已给出。

关于补充`preprocess`函数
需要我们补充的是一个lambda，重点在于理解调用该lambda的`sh::ProjectFunction`函数做了什么。
这个函数是针对每一个mesh上的顶点，计算球谐系数。

这个lambda的作用是，输入一个方向，返回H项

### js脚本部分
主要是新设定一下材质，在shader中获取预计算的结果后，点积球谐系数向量。
别忘了C++部分生成出来的cubemap文件copy到js实时渲染框架这里

## 作业3
整个作业框架，可以从WebGLRenderer.js中的Render函数，来看渲染流程。
如作业描述所说，有三个Pass
1. 计算ShadowMap所需深度
1. 计算并存储gBuffer
1. 我们要实现的本次作业的内容，SSR

### 前两个Pass
前两个Pass也可以看一看，就是把几何信息储存在了几张贴图中。贴图空间是存在浪费的，但是毕竟不是本次作业的重点，而且分开写也方便我们理解，无可厚非。

作业被拆分为了三步
### 第一步，实现对场景的直接光照
需要补充的不多，做两个事情即可：
1. 从gBuffer中读取漫反射贴图，计算光照结果，这里 \rho 取1
1. 主要是读取之前的gBuffer信息，与shadowMap信息做比较，算出阴影（即可见度）
二者相乘即可

### 第二步，实现间接光照

先实现RayMarch
在这个函数中，我们在世界坐标中做步进，利用了屏幕空间的gBuffer信息做光线与场景的相交判断。返回交点的世界坐标。
其中，相交判断，我们通过深度的比较去做。
初步可以先考虑取固定步长。之后再按照视频中所述使用mipmap步进做加速。
这里提一下为什么相交判断是这个
```
if(rayDepth - gBufferDepth > 0.0001)
```
深度的本质是这个位置距离相机的远近(不考虑reverseZ之类的事情)，所以值越大，离相机越远。
而gBufferDepth代表的是距离相机最近遮挡物，所以，当步进的光线的深度大于GBufferDepth的值时，代表我们的光线此时的位置被遮挡了（或者说位于物体内部），于是，此时我们可以判断，光线已于场景相交。


## 作业4