package="crater"
version="1.0-1"
source={
	url="git://github.com/girvel-workshop/crater",
	tag="1.0-1"
}
description={
	summary="",
	homepage="http://girvel.xyz",
	license="MIT"
}
dependencies={
	"lua >= 5.1, < 5.4"
}
build={
	type="builtin",
	modules={
		crater="crater.lua",
		_girvel="_girvel.lua"
	}
}