var gulp = require('gulp'),
    gutil = require('gulp-util'),
    sass = require('gulp-sass'),
    connect = require('gulp-connect'),
    uglify = require('gulp-uglify'),
    concatCss = require('gulp-concat-css'),
    minifycss = require('gulp-minify-css'),
    concat = require('gulp-concat');

var jsSources = ['../../assets/js/*.js'],
    cssSources = ['../../assets/css/*.css'],
    htmlSources = ['**/*.html'],
    outputDir = '../../assets';


gulp.task('log', function() {
  gutil.log('== My First Task ==')
});

gulp.task('copy', function() {
  gulp.src('index.html')
  .pipe(gulp.dest(outputDir))
});

gulp.task('css', function () {
  return gulp.src(cssSources)
    .pipe(concatCss("bundle.min.css"))
  	.pipe(minifycss())
    .pipe(gulp.dest(outputDir));
});


gulp.task('js', function() {
  gulp.src(jsSources)
  .pipe(uglify())
  .pipe(concat('script.min.js'))
  .pipe(gulp.dest(outputDir))
  .pipe(connect.reload())
});

gulp.task('watch', function() {
  gulp.watch(jsSources, ['js']);
  gulp.watch(cssSources, ['css']);
  gulp.watch(htmlSources, ['html']);
});

gulp.task('connect', function() {
  connect.server({
    root: '.',
    livereload: true
  })
});

gulp.task('html', function() {
  gulp.src(htmlSources)
  .pipe(connect.reload())
});

gulp.task('default', ['html', 'css', 'js', 'connect', 'watch']);