import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/browse.dart';
import '../data/models/track.dart';
import '../state/player_controller.dart';
import 'pages/browse_page.dart';

Future<void> openBrowseItem(
  BuildContext context,
  BrowseItem item, {
  List<Track>? queue,
}) async {
  final player = context.read<PlayerController>();
  if (item.isPlayable) {
    await player.playTrack(item.track!, context: queue ?? [item.track!]);
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BrowsePage(
        browseId: item.id,
        params: item.params,
        title: item.title,
        kind: item.kind,
        thumbnail: item.thumbnail,
      ),
    ),
  );
}

Future<void> openArtist(
  BuildContext context, {
  required String artistId,
  required String artistName,
  String? thumbnail,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BrowsePage(
        browseId: artistId,
        title: artistName,
        kind: MediaKind.artist,
        thumbnail: thumbnail,
      ),
    ),
  );
}

Future<void> openAlbum(
  BuildContext context, {
  required String albumId,
  required String albumName,
  String? thumbnail,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BrowsePage(
        browseId: albumId,
        title: albumName,
        kind: MediaKind.album,
        thumbnail: thumbnail,
      ),
    ),
  );
}
