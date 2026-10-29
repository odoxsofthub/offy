import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/document_payload_utils.dart';
import '../../../data/models/profile_response_model.dart';
import '../../viewmodels/profile/profile_provider.dart';
import '../common/chat/app_document_launcher.dart';
import 'profile_doc_card.dart';
import '../../../../l10n/app_localizations.dart';

class DocsTabContent extends StatefulWidget {
  final ProfileModel profile;
  final ScrollPhysics? physics;

  const DocsTabContent({super.key, required this.profile, this.physics});

  @override
  State<DocsTabContent> createState() => _DocsTabContentState();
}

class _DocsTabContentState extends State<DocsTabContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileProvider>().reloadAllDocuments();
    });
  }

  @override
  void didUpdateWidget(DocsTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      context.read<ProfileProvider>().reloadAllDocuments();
    }
  }

  bool _isPdf(ProfileDocumentModel doc) {
    final lowerKind = (doc.kind ?? '').toLowerCase();
    return lowerKind == 'pdf' ||
        lowerKind == 'application/pdf' ||
        (doc.mimetype ?? '').toLowerCase().contains('pdf') ||
        (doc.filename ?? doc.name).toLowerCase().endsWith('.pdf') ||
        doc.imageUrl.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ProfileProvider>();
    final docs = widget.profile.documents;

    return CustomScrollView(
      key: widget.key,
      physics: widget.physics ?? const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        if (docs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Text(
                  AppLocalizations.of(context)?.noDocumentsFound ??
                      'No documents found',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFA49D95)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(top: 0.h, bottom: 24.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                List.generate(docs.length, (index) {
                  final doc = docs[index];
                  final isLast = index == docs.length - 1;
                  final docPayload = provider.getDocPayload(doc.id);
                  final isLoadingPayload = provider.isDocLoading(doc.id);

                  final card = ProfileDocCard(
                    label: doc.name,
                    imageUrl: doc.imageUrl,
                    filename: doc.filename,
                    mimetype: doc.mimetype,
                    kind: doc.kind,
                    fileSize: doc.fileSize,
                    docPayload: docPayload,
                    isLoadingPayload: isLoadingPayload,
                    fit: BoxFit.cover,
                    onTap: () {
                      final rawUrl = doc.imageUrl.isNotEmpty
                          ? doc.imageUrl
                          : (doc.type == 'company_id' && doc.id <= 0
                                ? '/api/mobile/v1/profile/id-card'
                                : '');
                      final url = rawUrl.startsWith('/')
                          ? '${ApiConstants.baseUrl}$rawUrl'
                          : rawUrl;

                      final isPdf = _isPdf(doc);
                      // Pass bytes if already loaded or inline; otherwise null so the viewer opens at once and streams the file.
                      final downloadPayload = provider.getDocDownload(doc.id);
                      final bytes = isPdf
                          ? null
                          : (downloadPayload != null
                              ? DocumentPayloadUtils.extractBytes(downloadPayload)
                              : (url.isEmpty
                                  ? DocumentPayloadUtils.extractBytes(
                                      provider.getDocPayload(doc.id),
                                    )
                                  : null));

                      AppDocumentLauncher.open(
                        context,
                        path: url,
                        bytes: bytes,
                        name: doc.filename ?? doc.name,
                        kind:
                            doc.kind ??
                            doc.mimetype ??
                            (doc.type == 'company_id' && doc.id <= 0
                                ? 'image'
                                : doc.type),
                      );
                    },
                  );

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      children: [
                        card,
                        if (!isLast) SizedBox(height: 16.h),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }
}
