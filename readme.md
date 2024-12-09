# 随便写点东西

## 作业0
据网上的说法，index.html里改个东西，防止模型加载有问题。

## 作业1
普通shadowmap中，值得注意的点是，要构建了一个正交的矩阵，这意味着计算出来的是平行光下的阴影。
考虑加一个bias，此处使用的是这个公式：bias = max(base_bias * (1.0 - cos(normal, light_dir)), min_bias)

PCF中，值得注意的是，我们随机生成的采样点区域是[-1, 1]，需要再设置一个filterRange
另外就是，uv的偏移是要除以Shadowmap_Size的。

PCSS中，相比PCF，也就是通过遮挡物的平均深度，去确定了一个更合适的filterRange.
重点是用随机采样方式，计算出uv附近的平均深度，再用平均深度确定filterRange范围。

