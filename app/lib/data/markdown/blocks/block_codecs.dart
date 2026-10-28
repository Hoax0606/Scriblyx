import 'block_codec.dart';
import 'toggle_block_codec.dart';

/// 표준 마크다운으로 표현되지 않는 블록들의 변환 규칙.
///
/// 블록 종류를 추가할 때 고치는 곳은 여기 한 줄과 새로 만드는 파일뿐이다.
/// 앞에 둔 규칙부터 물어본다.
const blockCodecs = <BlockCodec>[ToggleBlockCodec()];
